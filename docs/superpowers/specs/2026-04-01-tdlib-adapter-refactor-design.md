# TDLib Adapter 重构设计

- 日期：2026-04-01
- 设计状态：已与用户确认
- 范围：`lib/app/services`、认证/流水线控制器、TDLib 相关测试

## 1. 目标

本轮重构解决当前 TDLib 集成边界混乱的问题，目标如下：

- 将 TDLib 协议交互独立抽象为 `TdlibAdapter`；
- 将启动流程收敛为显式状态机：`init -> setParams -> setProxy -> auth`；
- 统一 TDLib 错误模型，保留原始 `code/message` 与调用上下文；
- 启动时完成 schema 能力探测，运行期只走固定分支；
- 为 Adapter 增加可稳定运行的集成测试，至少覆盖 `addProxy/getProxies/auth`。

遵循项目约束：不引入静默 fallback、不用 mock 成功路径掩盖失败、错误显式暴露。

## 2. 现状问题

当前 `TelegramService` 同时承担了以下职责：

- TDLib 初始化与 transport 启动；
- 授权状态监听与配置推进；
- `setTdlibParameters` 与代理兼容逻辑；
- 认证请求发送；
- 业务请求（聊天列表、消息拉取、转发、撤销）；
- TDLib 错误转译。

这会带来几个具体问题：

- 启动推进依赖 update 回调中的条件分支，不是显式状态机；
- 代理兼容通过运行中失败后回退 payload，属于动态猜测；
- 错误模型只有 `TdlibRequestException(code/message)`，缺少请求名、阶段、原始异常等结构化信息；
- 服务层难以单独测试，协议问题与业务问题耦合。

## 3. 方案选型

采用“协议内聚方案”：

- `TdClientTransport` 保持最小职责，只做 TDLib client 与 request/response 关联；
- 新增 `TdlibAdapter`，集中处理 TDLib 协议语义；
- `TelegramService` 退化为业务编排层，只依赖 adapter 能力；
- 控制器继续依赖 `TelegramGateway`，避免 UI 层大范围改造。

不采用本轮额外引入 `AuthSessionCoordinator` 的激进拆分，以控制变更范围。

## 4. 架构设计

### 4.1 模块划分

#### `TdClientTransport`

职责：

- 创建/停止 TDLib client；
- 轮询 `tdReceive`；
- 分发 update；
- 维护 pending request。

约束：

- 不感知 TDLib schema 能力；
- 不做业务错误分类；
- 不做代理兼容分支。

#### `TdlibAdapter`

职责：

- 初始化 TDLib runtime；
- 启动状态机推进；
- schema 能力探测；
- `setTdlibParameters` / `addProxy` / `getProxies` / `disableProxy`；
- 认证请求提交与授权状态流转；
- 统一 TDLib 错误包装。

对外暴露：

- `start()`
- `submitPhoneNumber()`
- `submitCode()`
- `submitPassword()`
- `send()` / `sendWithTimeout()`（供业务层请求其它 TDLib 方法）
- `authorizationStates`
- `connectionStates`
- `startupStates`
- `capabilities`

#### `TelegramService`

职责：

- 业务语义：列会话、读消息、转发、撤销、媒体预下载；
- 使用 adapter 提供的协议能力；
- 不再管理参数设置、代理探测与授权推进。

### 4.2 依赖注入

依赖关系调整为：

- `TdClientTransport` <- 被 `TdlibAdapter` 注入
- `TdlibCredentials` <- 被 `TdlibAdapter` 注入
- `TelegramService` <- 依赖 `TdlibAdapter`
- `AuthController` / `PipelineController` <- 继续依赖 `TelegramGateway`

在 `bindings.dart` 中注册：

- `TdClientTransport`
- `TdlibAdapter`
- `TelegramService`

## 5. 启动状态机

新增 `TdlibStartupState`：

- `idle`
- `init`
- `setParams`
- `setProxy`
- `auth`
- `ready`
- `failed`
- `closed`

状态机规则：

1. `start()` 从 `idle/failed/closed` 进入 `init`；
2. 初始化 TDLib runtime 与 transport，订阅 update；
3. 主动查询 `GetAuthorizationState`；
4. 如果当前为 `AuthorizationStateWaitTdlibParameters`：
   - 进入 `setParams`，发送 `SetTdlibParameters`；
   - 再进入 `setProxy`，按已探测 schema 分支配置代理；
   - 完成后进入 `auth`；
5. 如果当前已越过 `waitTdlibParameters`：
   - 仍执行一次基于能力探测的代理同步；
   - 然后进入 `auth`；
6. 收到 `AuthorizationStateReady` 时进入 `ready`；
7. 收到 `AuthorizationStateClosed` 时进入 `closed`；
8. 任一步骤失败进入 `failed` 并抛出结构化错误。

注意：

- 不在运行中根据某次请求报错临时切换 schema；
- 状态机变迁通过 adapter 内部统一维护；
- 控制器只消费授权状态，不消费内部启动细节。

## 6. 版本能力探测

新增 `TdlibSchemaCapabilities`，先只包含：

- `addProxyMode`
  - `flatArgs`
  - `nestedProxyObject`

探测原则：

- 在 adapter 启动阶段显式探测一次；
- 探测结果保存在内存中，整个进程生命周期内固定；
- 运行中不再猜测，也不因单次失败切换分支；
- 若探测无法得出稳定结果，直接抛错终止启动。

实现策略：

- 将探测逻辑提炼为独立组件，如 `TdlibSchemaProbe`；
- 探测依赖可控的底层 transport fake，以便测试；
- `TdlibAdapter` 仅消费最终探测结果，不内联猜测逻辑。

## 7. 错误模型

新增统一错误对象 `TdlibFailure`：

- `kind`: `rateLimit/network/auth/permission/tdlib/transport/unexpected`
- `code`: 原始 TDLib code，可空
- `message`: 原始 TDLib message
- `request`: 请求名，如 `addProxy`
- `phase`: 启动/认证/业务阶段，如 `setProxy/auth/fetchHistory`
- `cause`: 原始异常对象
- `stackTrace`

设计原则：

- `kind` 只做附加分类，不替代原始 `code/message`；
- `TdError`、超时、transport 异常统一映射到 `TdlibFailure`；
- 控制器与日志系统消费同一个错误对象；
- 现有文案分类逻辑保留，但改为基于 `TdlibFailure` 计算。

## 8. 测试策略

采用分层测试方案：

### 8.1 Adapter 集成测试

新增 `test/services/tdlib_adapter_test.dart`：

- 以 fake transport / fake TD request responder 驱动 adapter；
- 不 mock adapter 自己；
- 验证完整状态推进与请求分支。

覆盖最少场景：

- `addProxy`：`flatArgs` 分支；
- `addProxy`：`nestedProxyObject` 分支；
- `getProxies`：成功返回与类型异常；
- `auth`：`start -> waitTdlibParameters -> setParams -> setProxy -> waitPhone`；
- `auth`：`AuthorizationStateReady` 能解锁业务请求；
- 错误场景：代理配置失败、超时、TD error 结构化封装。

### 8.2 纯逻辑测试

新增：

- `test/domain/tdlib_failure_test.dart`
- `test/services/tdlib_schema_probe_test.dart`
- `test/services/tdlib_startup_state_machine_test.dart`

### 8.3 现有测试适配

- `td_error_classifier_test.dart` 改用新错误模型；
- `auth_pipeline_flow_test.dart` 仅保留控制器/UI 行为断言，避免测试协议细节。

## 9. 迁移步骤

1. 先引入新错误模型与分类器适配；
2. 再引入 schema capability 与 probe；
3. 再实现 `TdlibAdapter` 和启动状态机；
4. 将 `TelegramService` 改为依赖 adapter；
5. 更新依赖注入；
6. 补齐测试并回归。

## 10. 风险与控制

风险：

- 授权状态推进顺序变化可能影响现有登录流程；
- 代理兼容逻辑从“失败回退”改为“启动探测”，若探测设计不稳会直接影响启动；
- 控制器错误处理切换到新模型后，旧测试断言需要同步更新。

控制措施：

- 先写 adapter 集成测试再落地实现；
- 让 `TelegramService` 外部接口尽量稳定；
- 每一层错误都保留原始 request/phase 信息，便于快速回溯。
