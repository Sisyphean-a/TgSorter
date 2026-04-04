# TDLib Raw JSON 迁移交接文档

## 文档目的

这份文档用于在新对话中快速接手当前迁移与调试工作，避免重复梳理上下文。

适用场景：

- 继续排查 Windows F5 启动问题
- 继续完成 TDLib raw JSON 迁移收口
- 理解当前代码为什么会在登录页出现“授权未就绪”

---

## 当前结论

截至当前会话，TDLib raw JSON 迁移的主体代码已经完成，测试和 `flutter analyze` 均通过，但 Windows 运行时仍存在少量“桥接层残留噪音 + 启动时序问题”。

当前最重要的判断：

1. raw transport、wire envelope、response reader、auth/connection 本地状态模型、proxy/chat/message DTO、TelegramService 业务解析迁移都已经落地。
2. `TdClientTransport` 仍然是一个“typed 兼容壳”，会把 raw update 再尝试转回 `TdObject`，这会对新 DLL schema 下的某些 update 产生非致命 parse error 噪音。
3. 登录页看到的“TDLib 授权未就绪，无法执行当前请求”不是 TDLib 原生错误，而是应用层业务请求太早触发。

---

## 已完成的主要改动

### 1. Raw transport + 日志

已完成：

- `lib/app/services/td_raw_transport.dart`
- `lib/app/services/td_json_logger.dart`
- `lib/app/services/td_wire_message.dart`
- `lib/app/services/td_response_reader.dart`

能力：

- 直接走 `TdPlugin.instance.tdCreate/tdSend/tdReceive`
- debug 模式输出完整：
  - `TD SEND`
  - `TD RECV`
  - `TD UPDATE`
  - `TD PARSE ERROR`

### 2. 本地状态与 DTO

已完成：

- `lib/app/services/td_auth_state.dart`
- `lib/app/services/td_connection_state.dart`
- `lib/app/services/td_proxy_dto.dart`
- `lib/app/services/td_chat_dto.dart`
- `lib/app/services/td_message_dto.dart`
- `lib/app/services/td_update_parser.dart`

### 3. 业务层迁移

已完成：

- `lib/app/services/telegram_service.dart`
- `lib/app/domain/message_preview_mapper.dart`
- `lib/app/shared/presentation/widgets/message_viewer_card.dart`

说明：

- 业务层 chat / me / getOption(my_id) / history / forwardMessages / deleteMessages / downloadFile 已改为读本地 DTO
- UI-facing 层已去除对 `package:tdlib/td_api.dart` 的直接依赖

### 4. 启动链修复

已完成的修复：

- `TdNativePlugin.registerWith()` 需要在 `TdPlugin.initialize(...)` 之前调用
- `TdRawTransport` 改成按启动时懒取 `TdPlugin.instance`，避免构造时锁死 stub
- `detectCapabilities()` 从“TDLib 初始化后立刻执行”改为“`setTdlibParameters` 之后执行”

对应文件：

- `lib/app/services/tdlib_adapter_support.dart`
- `lib/app/services/td_raw_transport.dart`
- `lib/app/services/tdlib_adapter.dart`

---

## 当前测试状态

本会话里已经通过的关键验证：

```text
flutter test test/services/td_raw_transport_test.dart
flutter test test/services/td_json_logger_test.dart
flutter test test/services/td_response_reader_test.dart
flutter test test/services/td_wire_auth_parser_test.dart
flutter test test/services/td_wire_chat_parser_test.dart
flutter test test/services/td_wire_message_parser_test.dart
flutter test test/services/td_proxy_dto_test.dart
flutter test test/services/tdlib_schema_probe_test.dart
flutter test test/services/tdlib_startup_state_machine_test.dart
flutter test test/services/tdlib_adapter_test.dart
flutter test test/services/tdlib_adapter_lifecycle_test.dart
flutter test test/controllers/pipeline_controller_test.dart
flutter test test/integration/auth_pipeline_flow_test.dart
flutter test test/domain/message_preview_mapper_test.dart
flutter analyze
```

结论：

- 当前问题不是测试失败，而是 Windows 运行时真实 TDLib DLL 与兼容桥接层之间的残留交互问题。

---

## 当前运行时现象

### 现象 1：`addedProxy` 的 typed update parse error

用户提供的日志片段：

```text
[TD PARSE ERROR] stage=typed_update context=type=addedProxy reason=Bad state: TDLib payload cannot be converted to TdObject
payload={"@type":"addedProxy",...}
```

根因判断：

- `TdClientTransport` 仍在监听 raw update 后尝试 `convertToObject(jsonEncode(payload))`
- DLL 当前会发出 `addedProxy` 这类强类型桥接不认识或不兼容的 update
- 所以在：
  - `lib/app/services/td_client_transport.dart`
  - `_forwardUpdate()`
  - `_decodePayload()`
 这里会记录 parse error

重要说明：

- 这条错误目前判断为“噪音但不是主要致命问题”
- 因为 raw transport 仍能继续收到后续 update，如 `updateConnectionState` / `updateOption`

### 现象 2：登录页出现“TDLib 授权未就绪，无法执行当前请求”

用户截图与描述表明，登录页会弹：

```text
Bad state: TDLib 授权未就绪，无法执行当前请求
```

根因判断：

- 这不是 TDLib 原生日志，而是应用层抛的 `StateError`
- 抛出位置：
  - `lib/app/services/telegram_service.dart`
  - `_requireAuthorizationReady()`

更具体的触发链路：

1. `PipelineCoordinator` 是全局常驻协调器
2. 它在 `onInit()` 里订阅 `connectionStates`
3. 只要连接状态变成 `Ready`，就会尝试自动 `fetchNext()`
4. 但此时用户仍在登录页，授权流程未完成
5. `fetchNext()` 进入 `TelegramService.fetchNextMessage()`
6. `_requireAuthorizationReady()` 抛出 `TDLib 授权未就绪`

这意味着：

- “连接 ready” 不等于“授权 ready”
- 目前 `PipelineCoordinator` 的自动取消息条件过宽

---

## 当前最值得优先修复的问题

### P1：修正 `PipelineCoordinator` 的自动拉取条件

优先级最高。

建议方向：

- 不要仅凭 `connectionStateReady` 就触发 `fetchNext()`
- 应当增加“授权 ready”条件
- 可选做法：
  - 让 `PipelineCoordinator` 同时监听 auth state
  - 或由 capability ports / `TelegramService` 暴露授权就绪状态
  - 或只在进入 pipeline 页面且授权 ready 后再允许自动取消息

如果不修：

- 登录页阶段只要连接状态 ready，就可能提前触发业务请求
- 继续造成“授权未就绪”异常提示

### P2：让 `TdClientTransport` 不再尝试 typed 解析所有 raw update

优先级次高。

建议方向：

- 既然 runtime 主要已经走 raw update parser，则 `TdClientTransport._forwardUpdate()` 的 typed update bridge 可以进一步收口
- 至少不要把无法识别的 raw-only update 继续上抛为错误噪音

候选方案：

1. 只在需要 typed 兼容的旧路径里使用 `TdClientTransport.updates`
2. 对未知 update type 直接忽略，而不是抛 `TDLib payload cannot be converted to TdObject`
3. 更彻底：最终删除 typed update bridge，仅保留 typed request response bridge，甚至完全退出

### P3：完善错误历史 UI 体验

这是用户明确提出的不爽点：

- 当前错误历史一次只能复制一行
- 用户已经明确表示这个体验很差

建议方向：

- 改成整块 `SelectableText` / 单块文本区域
- 或加“复制全部”按钮
- 或提供日志导出按钮

这不是当前启动失败的根因，但是真实痛点。

---

## 关键文件索引

### 启动与传输

- `lib/app/core/di/app_bindings.dart`
- `lib/app/services/tdlib_adapter_support.dart`
- `lib/app/services/td_raw_transport.dart`
- `lib/app/services/td_client_transport.dart`
- `lib/app/services/tdlib_adapter.dart`

### 状态与更新解析

- `lib/app/services/td_auth_state.dart`
- `lib/app/services/td_connection_state.dart`
- `lib/app/services/td_update_parser.dart`

### 代理与 schema

- `lib/app/services/tdlib_schema_probe.dart`
- `lib/app/services/tdlib_proxy_manager.dart`
- `lib/app/services/td_proxy_dto.dart`

### 业务层

- `lib/app/services/telegram_service.dart`
- `lib/app/features/auth/application/auth_coordinator.dart`
- `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- `lib/app/features/settings/application/settings_coordinator.dart`

### UI

- `lib/app/features/auth/presentation/auth_page.dart`
- `lib/app/features/settings/presentation/settings_page.dart`
- `lib/app/shared/presentation/widgets/message_viewer_card.dart`

### VS Code 启动配置

- `.vscode/launch.json`

---

## 推荐的新对话开场语

下一轮对话建议直接使用下面这段：

> 请先阅读 `docs/tdlib-raw-json-migration-handoff-2026-04-01.md`。当前 raw JSON 迁移主体已完成，测试与 analyze 都通过。现在优先处理两个运行时问题：  
> 1. `PipelineCoordinator` 在“连接 ready 但授权未 ready”时过早自动 `fetchNext()`，导致登录页出现“TDLib 授权未就绪，无法执行当前请求”；
> 2. `TdClientTransport` 仍会对 `addedProxy` 等 raw-only update 做 typed 解析并输出噪音 parse error。  
> 先修第 1 个，再决定是否收口第 2 个。不要重新做大规模调研。

---

## 当前状态一句话总结

当前不是“迁移没做完”，而是“迁移主体已完成，但还剩最后一段运行时收口：授权时序与 typed bridge 残留噪音”。
