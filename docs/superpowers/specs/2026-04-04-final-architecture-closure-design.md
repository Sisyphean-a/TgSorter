# Final Architecture Closure Design

## 1. 背景

TgSorter 已经完成一次较大规模的架构演化：

- `features/*` 成为唯一真实业务入口
- `shared/presentation/*` 承担跨 feature 复用展示部件
- `pipeline` 已经完成一轮 coordinator 薄化，消息流、生命周期、媒体刷新和错误映射被拆到独立协作者
- compat / legacy 层已经移除

当前项目已经从“带兼容壳的迁移中间态”进入“可维护的模块化单体”阶段，但仍存在最后一批未完全收口的问题：

1. `SettingsCoordinator` 仍承担过多职责
2. `AuthCoordinator` 仍混合授权状态机、错误映射和路由跳转
3. `TelegramGateway` 仍是过渡期聚合接口，业务模块尚未完全收敛到 capability ports
4. DI 已模块化，但仍偏向通过大接口集中注入
5. `AppErrorController` 仍以字符串协议驱动 UI，而不是结构化错误事件
6. feature 间的边界方向已经正确，但收口程度不一致，后续开发仍有把逻辑重新堆回“大协调器”的风险

本轮设计目标不是再次做渐进兼容式迁移，而是基于当前正确方向，完成一次性“最终收口”，让当前架构进入稳定可长期维护的稳态。

## 2. 目标

### 2.1 主要目标

- 保留当前 feature-first 架构方向，不推翻现有项目主结构
- 让 `auth`、`settings`、`pipeline` 三个 feature 的 application 层边界风格一致
- 删除或彻底降级 `TelegramGateway` 这类过渡聚合接口
- 让业务模块只依赖最小能力接口（capability-based ports）
- 把错误系统升级为结构化事件流
- 让 `core/di` 成为真正的 composition root，不再承载业务语义
- 维持用户可见行为不变，只调整结构与职责边界

### 2.2 非目标

- 不切换状态管理方案，仍使用 GetX
- 不引入重型 Clean Architecture 模板或多 package 结构
- 不重写 `pipeline` 主流程行为
- 不修改现有持久化数据结构语义
- 不引入新的兼容层或中间过渡层

## 3. 问题陈述

### 3.1 Settings 仍处于半收口状态

`SettingsCoordinator` 目前同时承担：

- saved / draft 双态维护
- 分类目标编辑
- 来源会话、抓取方向、代理、快捷键、批处理参数编辑
- 设置保存与提交
- proxy 变化后的 restart 策略
- 会话列表加载
- `PipelineSettingsReader` 契约实现

这使得 settings feature 虽然已经拆出了一部分 service，但对页面和其他 feature 来说，仍表现为一个大而全的应用层中心。

### 3.2 Auth 仍存在应用层与框架层耦合

`AuthCoordinator` 目前混合了：

- TDLib 授权状态到 UI stage 的映射
- start / restart / submit* 入口
- TDLib 错误到用户文案的映射
- `Get.offNamed(...)` 路由跳转
- 通过 settings 变更代理并触发 retry

这导致 auth feature 的 application 层不能被视为纯编排层。

### 3.3 聚合型 TelegramGateway 仍是历史过渡语义

当前代码中已经存在：

- `AuthGateway`
- `SessionQueryGateway`
- `MessageReadGateway`
- `MediaGateway`
- `ClassifyGateway`
- `RecoveryGateway`

但 `TelegramGateway` 仍把这些能力重新聚合到一个大接口中，DI 和部分 feature 仍通过它取依赖。这意味着 capability-based 方向已经建立，但还没有彻底落地。

### 3.4 错误系统表达力不足

`AppErrorController` 当前以格式化后的字符串作为主载体，存在以下问题：

- 错误来源域不明确
- 错误级别无法表达
- 结构与展示耦合
- 后续如要支持操作建议、重试动作、筛选或更丰富的 UI 呈现，会被现有字符串协议限制

### 3.5 装配边界仍不够“能力导向”

虽然 `core/di` 已经模块化，但当前仍能看到以下问题：

- 多个 feature 通过同一个大接口取能力
- feature module 的依赖声明还不够最小化
- DI 图没有完全反映真实能力边界

这会在未来继续扩大测试装配成本和模块间隐式耦合。

## 4. 架构决策

本轮选择的策略是：

**保留当前 feature-first 模块化单体结构，在现有基础上做“最终收口式演化”。**

不选择以下两种路径：

### 4.1 不选“继续渐进式小步拆”

原因：

- 会长期保留中间态
- 用户目标是一次性解决剩余问题
- 当前项目已经足够接近最终态，继续小步拆收益下降

### 4.2 不选“重型架构翻新”

原因：

- 当前主方向已经正确
- 引入过重的 use case / repository / datasource 空壳会显著增加形式复杂度
- 现阶段问题是边界未完全收口，不是架构范式错误

## 5. 目标架构

目标结构如下：

```text
features/
  auth/
    application/
    presentation/
    ports/
  settings/
    application/
    domain/
    presentation/
    ports/
  pipeline/
    application/
    presentation/
    ports/

services/
  telegram/
  tdlib/

shared/
  presentation/
  errors/

core/
  di/
  routing/
```

目标原则：

1. feature 只依赖自己声明的最小能力接口
2. application 只做编排，不做底层实现和框架跳转
3. services 只做外部系统适配与实现
4. shared 只容纳跨 feature 的稳定复用
5. composition root 只负责装配，不承载业务语义

## 6. 核心设计

### 6.1 Auth 收口设计

#### 保留 façade

- `AuthCoordinator`

#### 新增协作者

- `AuthLifecycleCoordinator`
- `AuthErrorMapper`
- `AuthNavigationPort`
- `GetxAuthNavigationAdapter`（名称可按现有命名风格微调）

#### 职责分配

`AuthCoordinator`：

- 作为页面面向的稳定 façade
- 暴露 `stage`、`loading`、错误可见状态
- 转发页面提交动作到生命周期协作者

`AuthLifecycleCoordinator`：

- 监听 `authStates`
- 管理 `bootstrap`
- 管理 `submitPhone / submitCode / submitPassword`
- 管理 `saveProxyAndRetry`
- 决定何时触发导航意图

`AuthErrorMapper`：

- 负责 `TdlibFailure` -> auth 域用户错误
- 负责 general error -> auth 域用户错误
- 输出结构化错误事件，而非字符串

`AuthNavigationPort`：

- 只表达导航意图，例如 `goToPipeline()`
- application 不直接依赖 Get 路由

#### 结果

auth feature 将从“协调器 + 框架跳转 + 错误拼接”的混合体，变为“薄 façade + 生命周期协作者 + 错误映射 + 导航 port”的稳定结构。

### 6.2 Settings 收口设计

#### 保留 façade

- `SettingsCoordinator`

#### 新增协作者

- `SettingsDraftCoordinator`
- `SettingsPersistenceService`
- `SettingsChatLoader`
- `SettingsRestartPolicy`

#### 保留并继续复用的现有协作者

- `CategorySettingsService`
- `ShortcutSettingsService`
- `ConnectionSettingsService`

#### 职责分配

`SettingsCoordinator`：

- 保持 settings 页 façade 地位
- 继续实现 `PipelineSettingsReader`
- 组合 draft、persistence、chat、restart 等协作者
- 暴露页面所需 observable

`SettingsDraftCoordinator`：

- 管理 `draft` / `saved` / `isDirty`
- 提供 `replace / update / commit / discard`

`SettingsPersistenceService`：

- 负责 `load` / `save`
- 负责将 `draft` 持久化并完成提交语义

`SettingsChatLoader`：

- 管理会话加载、错误和 loading 状态

`SettingsRestartPolicy`：

- 根据 `previous settings` 与 `next settings` 判断是否需要 `auth.restart()`

#### 结果

settings feature 将从“大协调器 + 一组零散 service”演化为“统一 façade + 明确协作者”的结构，并与 pipeline 的 application 风格保持一致。

### 6.3 Pipeline 一致性收口

pipeline 已完成较多拆分，本轮不再大拆，只做风格对齐与能力边界统一。

保留：

- `PipelineCoordinator`
- `PipelineFeedController`
- `PipelineLifecycleCoordinator`
- `PipelineMediaController`
- `PipelineErrorMapper`

本轮要求：

- pipeline 只依赖最小 ports
- pipeline 的错误输出也接入结构化错误系统
- pipeline 的 DI 与 auth/settings 保持一致的能力导向装配方式

### 6.4 Gateway / Port 收口

#### 现有 ports

- `AuthGateway`
- `SessionQueryGateway`
- `MessageReadGateway`
- `MediaGateway`
- `ClassifyGateway`
- `RecoveryGateway`

#### 新增 port

- `ConnectionStateGateway` 或等价命名

职责：

- 向需要消费连接状态的 feature 提供 `connectionStates`

#### 删除目标

- `TelegramGateway`

#### 装配规则

`TelegramService` 继续是实现类，但在 DI 层按 capability 注册，不再让业务模块依赖聚合总接口。

例如：

- auth 模块只取 `AuthGateway`
- settings 模块只取 `SessionQueryGateway` 与可选 `AuthGateway`
- pipeline 模块只取 `MessageReadGateway`、`MediaGateway`、`ClassifyGateway`、`RecoveryGateway`、`ConnectionStateGateway`

#### 结果

业务模块将只看到自己真正需要的能力边界，测试桩也可显著简化。

### 6.5 结构化错误系统

#### 新增模型

- `AppErrorEvent`
- `AppErrorScope`
- `AppErrorLevel`

建议字段：

- `scope`
- `level`
- `title`
- `message`
- `timestamp`
- 可选 `actionLabel`
- 可选 `actionKey` 或等价动作标识

#### 改造 `AppErrorController`

`AppErrorController` 改为：

- `currentError: Rxn<AppErrorEvent>`
- `errorHistory: List<AppErrorEvent>`
- `report(AppErrorEvent event)` 或等价结构化接口

#### feature mapper

- auth 使用 `AuthErrorMapper`
- pipeline 继续使用 `PipelineErrorMapper`，但输出 `AppErrorEvent`
- settings 如果需要 feature 级错误映射，则引入 `SettingsErrorMapper`

#### 展示层

`AppErrorPanel` 只做渲染，不再承担字符串协议解析。

#### 结果

错误系统从“字符串消息板”升级为“统一结构化错误流”，为未来更丰富的错误交互打基础。

### 6.6 DI / 路由 / 页面边界

#### DI

保留：

- `app_bindings.dart`
- `auth_module.dart`
- `settings_module.dart`
- `pipeline_module.dart`

但要求：

- `app_bindings.dart` 只做 composition root
- module 只声明本 feature 真实依赖
- 不再用总接口注入所有能力

#### 路由

`app_routes.dart` 只负责页面构造和参数装配。

#### 页面

页面层只依赖 feature façade：

- `AuthCoordinator`
- `SettingsCoordinator`
- `PipelineCoordinator`

页面层只负责：

- 展示
- 用户交互
- 调用 façade

页面层不承载业务规则；application 层也不直接操作框架路由。

## 7. 迁移策略

这轮虽然目标是一次性收口，但实施上采用强约束分阶段迁移。

### Batch 1: Ports 与错误系统

- 新增 `ConnectionStateGateway`
- 引入结构化错误模型
- 改造 `AppErrorController`
- 让 pipeline 先接入新错误流
- DI 具备 capability-based 注册基础

### Batch 2: Settings 收口

- 引入 `SettingsDraftCoordinator`
- 引入 `SettingsPersistenceService`
- 引入 `SettingsChatLoader`
- 引入 `SettingsRestartPolicy`
- 迁移 settings 页面与测试
- 保持 `PipelineSettingsReader` 契约稳定

### Batch 3: Auth 收口

- 引入 `AuthLifecycleCoordinator`
- 引入 `AuthErrorMapper`
- 引入 `AuthNavigationPort`
- 将 `Get.offNamed` 从 application 层移出
- 迁移 auth 页面与测试

### Batch 4: 删除过渡层并全量回归

- 删除 `TelegramGateway`
- 改造 module 装配到最终能力边界
- 清理残留旧接线
- 更新文档
- 执行全量回归并提交推送

## 8. 风险与对策

### 8.1 `SettingsCoordinator` 既是 façade 又实现 `PipelineSettingsReader`

风险：

- 迁移 settings 协作者时，容易影响 pipeline 对配置读取的稳定语义

对策：

- `SettingsCoordinator` 继续保留 `PipelineSettingsReader` 实现地位
- 其内部协作者重构不改变对外接口语义
- 为 `PipelineSettingsReader` 使用路径补充回归测试

### 8.2 auth 与 settings 在代理重启流程上存在交叉

风险：

- 容易在保存代理与 retry 流程上造成重复 restart 或行为漂移

对策：

- 把“是否需要 restart”统一收敛到 `SettingsRestartPolicy`
- auth 只调用 settings 的稳定保存入口

### 8.3 删除 `TelegramGateway` 会连锁影响 DI 与测试桩

风险：

- 很多测试可能默认依赖大接口桩

对策：

- 先完成 capability ports 接线
- 再批量替换测试桩
- 最后删除聚合接口

### 8.4 结构化错误迁移会影响页面测试断言

风险：

- 现有页面测试可能直接断言字符串

对策：

- 先保留 `AppErrorPanel` 最终渲染文案不变
- 只改变内部模型
- 页面测试优先断言渲染结果，不依赖内部表示

### 8.5 路由从 application 层抽出后，导航责任可能悬空

风险：

- 如果没有明确 port，application 会变成“知道要跳转但没人执行”

对策：

- 明确引入 `AuthNavigationPort`
- 在 DI 中提供 GetX adapter 实现

## 9. 测试策略

### 9.1 单元测试

新增或强化测试覆盖：

- `AuthLifecycleCoordinator`
- `AuthErrorMapper`
- `SettingsDraftCoordinator`
- `SettingsPersistenceService`
- `SettingsChatLoader`
- `SettingsRestartPolicy`
- `AppErrorController` 结构化事件行为

### 9.2 Feature Application 回归

保持并更新：

- `pipeline` application 测试
- `settings` application 测试
- `auth` 页面与流程测试

### 9.3 页面与集成回归

必须保留：

- `test/pages/*`
- `test/integration/auth_pipeline_flow_test.dart`
- `test/controllers/*`

### 9.4 全量验证

实现完成时至少执行：

- `timeout 60s dart analyze`
- `timeout 60s flutter test`

必要时按批次增加聚焦命令。

## 10. 验收标准

完成本轮后，应满足：

1. 项目中业务 feature 不再依赖 `TelegramGateway`
2. `TelegramGateway` 已被删除或不再对业务层可见
3. `AuthCoordinator` 不再直接执行框架路由跳转
4. `SettingsCoordinator` 已明显瘦身，只保留 façade 与 `PipelineSettingsReader` 职责
5. `AppErrorController` 已使用结构化错误事件而非字符串协议
6. `core/di` 已按 capability ports 装配依赖
7. 页面行为、授权流程、设置保存语义、pipeline 主流程行为与现有一致
8. 全量静态检查与测试通过

## 11. 最终判断

当前项目不需要推翻重做，也不适合切换到更重的架构范式。最合理的下一步，是基于现有 feature-first 模块化单体方向，完成这轮“最终收口式演化”。

本设计完成后，项目将从“已经合理但边界不完全对齐的稳态”升级为“边界完整、依赖最小化、可长期维护的最终稳态”。
