# Pipeline Coordinator Thinning Design

## Context

在完成最终架构演化之后，`features/*` 已经成为唯一真实入口，compat/legacy 层也已经被移除。但 `PipelineCoordinator` 仍然保留了过多流程细节，当前文件约 800 行，同时承担了以下职责：

- 页面入口方法与响应式状态暴露
- auth / connection / settings 监听
- auto fetch 与 transaction recovery 触发
- 消息初始加载、翻页追加、可见项兜底
- 媒体准备、轮询刷新、prepared message merge
- preview prefetch 与 remaining count 刷新
- TDLib 错误分类与用户可见错误文案映射
- Telegram gateway adapter 内嵌实现

这使得 `PipelineCoordinator` 已经超出“协调器”职责，变成半个应用层总管。下一轮优化目标是把它收回到真正的 page-facing orchestrator 角色。

## Goal

将 `PipelineCoordinator` 演化为薄编排层：

- 页面 API 维持稳定或只做小幅、合理的应用层接口调整
- coordinator 文件体积显著下降
- 生命周期、消息装载、媒体刷新、错误翻译形成独立应用层子模块
- 新边界能够被单独测试，并支持后续持续演化

## Non-Goals

本轮不做以下事项：

- 不引入 command bus、事件总线、状态机框架等重型抽象
- 不改动页面层主要交互语义
- 不重写 `PipelineActionService`、`PipelineNavigationService` 等已稳定子服务
- 不扩展新功能，只做结构收口

## Current Problems

### 1. Coordinator 角色失真

`PipelineCoordinator` 既暴露页面入口，又直接实现消息装载、媒体轮询、错误翻译等细节。这会让：

- 页面入口变得难以理解
- 生命周期行为难以定位
- 测试只能围绕“大而全”的 coordinator 写，边界模糊

### 2. 变化原因混杂

当前一个文件同时响应多种变化来源：

- 连接状态变化
- 鉴权状态变化
- 设置变化
- 当前消息变化
- 媒体下载变化
- 剩余数刷新变化

任何一个流程调整，都容易在 coordinator 内造成连锁修改。

### 3. 生命周期与消息流耦合

auto fetch / recovery 触发逻辑、本地 cache 推进逻辑、timer 轮询逻辑混在一起，导致：

- `onInit` / `onReady` / `onClose` 难以单独验证
- “何时开始拉取”“何时恢复事务”“何时停止轮询”不够清晰

### 4. 基础设施适配细节泄漏到主文件

`_TelegramClassifyGateway` 等 adapter 内嵌在 coordinator 文件尾部，属于基础设施适配细节，不应该继续占据主业务文件。

## Design Principles

### 1. Coordinator 只负责页面编排

`PipelineCoordinator` 保留：

- 页面直接调用的方法
- 页面依赖的响应式状态暴露
- 子模块的装配与最薄一层转发
- 生命周期入口

它不再直接持有复杂流程细节。

### 2. 按“变化原因”拆分，而不是按工具函数拆分

拆分边界不是为了把私有方法搬家，而是按真实职责收口：

- 生命周期触发
- 消息流装载
- 媒体刷新
- 错误映射

### 3. 先形成稳定子模块，再考虑进一步模式化

本轮先收紧边界，不额外引入更重的架构模式。只有当这些子模块稳定运行后，才值得评估是否继续抽象成更正式的 use-case / session 模式。

## Target Architecture

### PipelineCoordinator

保留为页面应用入口，职责如下：

- 通过 `runtimeState` 向页面暴露响应式状态
- 提供页面调用的公开方法：
  - `fetchNext`
  - `prepareCurrentMedia`
  - `skipCurrent`
  - `runBatch`
  - `classify`
  - `showPreviousMessage`
  - `showNextMessage`
  - `undoLastStep`
  - `retryNextFailed`
  - `recoverPendingTransactionsIfNeeded`
- 在公开方法中调用下层子模块
- 管理 `onInit` / `onReady` / `onClose`

### PipelineLifecycleCoordinator

负责生命周期与自动触发逻辑：

- 监听 auth state / connection state
- 监听 settings 变化
- 处理 auto fetch 触发条件
- 处理 recovery 触发条件
- 响应 source chat / fetch direction 变化时的 pipeline reset

它不负责具体消息加载与媒体刷新实现，只负责决定“何时触发什么”。

### PipelineFeedController

负责消息流与预取逻辑：

- 初始加载消息页
- 追加更多消息
- 维护 tail message id
- ensure visible message
- prefetch upcoming previews
- remaining count refresh
- remaining count 的增减维护

它依赖现有的 `PipelineNavigationService`、`RemainingCountService` 和 message read/media read capability。

### PipelineMediaController

负责媒体准备与轮询刷新：

- `prepareCurrentMedia`
- `refreshCurrentMediaIfNeeded`
- `_needsMediaRefresh`
- `_syncPreparingState`
- `_mergePreparedMessage`
- timer 的启停

它不负责决定页面何时切换消息，只负责当前消息媒体状态的推进。

### PipelineErrorMapper

负责错误翻译与上报：

- `TdlibFailure -> 用户可见错误`
- FloodWait / network / auth / permission 的文案规则
- 一般异常的统一包装

它只关心错误语义，不关心具体业务流程。

### Pipeline Gateway Adapters

将以下内嵌类迁移到独立文件：

- `_TelegramClassifyGateway`
- `_TelegramMediaGateway`
- `_TelegramMessageReadGateway`
- `_TelegramRecoveryGateway`

这样 coordinator 文件只保留业务编排，不再夹杂基础设施适配代码。

## File Plan

### Create

- `lib/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart`
- `lib/app/features/pipeline/application/pipeline_feed_controller.dart`
- `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- `lib/app/features/pipeline/application/pipeline_error_mapper.dart`
- `lib/app/features/pipeline/application/pipeline_gateway_adapters.dart`

### Modify

- `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- `test/features/pipeline/application/pipeline_coordinator_test.dart`
- `test/controllers/pipeline_controller_test.dart`

### Create Tests

- `test/features/pipeline/application/pipeline_lifecycle_coordinator_test.dart`
- `test/features/pipeline/application/pipeline_feed_controller_test.dart`
- `test/features/pipeline/application/pipeline_media_controller_test.dart`
- `test/features/pipeline/application/pipeline_error_mapper_test.dart`

## Data Flow

### Page -> Coordinator

页面仍然只面向 `PipelineCoordinator` 调用公开方法，不直接依赖新拆出的子模块。

### Coordinator -> Child Modules

- 生命周期相关入口转发给 `PipelineLifecycleCoordinator`
- 消息流与预取相关入口转发给 `PipelineFeedController`
- 媒体相关入口转发给 `PipelineMediaController`
- 异常处理统一委托给 `PipelineErrorMapper`

### Shared Runtime State

为了避免状态复制与同步开销，这一轮继续保留 `PipelineRuntimeState` 作为共享状态容器。新拆出的子模块通过显式注入 `PipelineRuntimeState`、`PipelineNavigationService`、`PipelineSettingsReader` 等依赖来协作。

也就是说：

- **状态仍然共享**
- **流程逻辑拆开**
- **页面入口不变**

这是当前阶段风险最低、收益最高的方案。

## Testing Strategy

### Focused Tests

新增聚焦测试分别验证：

- lifecycle 模块的 auto fetch / recovery / settings change 响应
- feed 模块的 load / append / ensure visible / remaining count / prefetch
- media 模块的 prepare / refresh / timer / merge
- error mapper 的错误翻译规则

### Coordinator Tests

`PipelineCoordinator` 的测试从“细节行为全覆盖”收敛为“薄编排语义”：

- 是否把动作委派给对应子模块
- 是否维持页面可见状态
- 是否保持公开 API 语义不变

### Regression Coverage

继续保留并回归：

- `test/features/pipeline/application/*`
- `test/controllers/pipeline_controller_test.dart`
- 全量 `flutter test`

## Risks

### 1. 响应式状态脱节

如果子模块在更新 `runtimeState` 时边界不清，可能出现页面状态不同步。解决方式是保留单一 `PipelineRuntimeState`，避免复制 state。

### 2. Auto Fetch / Recovery 时序回归

生命周期逻辑拆出后，最容易出现触发顺序变化。需要用独立测试覆盖：

- 未授权不拉取
- recovery 未完成时先恢复
- settings 变化时 reset 后重新拉取

### 3. Media Timer 泄漏

媒体轮询拆出后，要重点验证：

- 切换消息时 timer 停止
- 轮询完成后 timer 停止
- `onClose` 时资源释放

### 4. 结构优化沦为文件搬家

如果只是把私有方法搬出而没有重新定义职责，收益会很低。本轮必须以“边界重塑”为验收标准，而不是以“文件数量增加”为标准。

## Success Criteria

本轮完成后，应满足：

- `PipelineCoordinator` 显著瘦身，不再直接实现主要流程细节
- 生命周期、消息流、媒体刷新、错误翻译具备稳定且可单测的独立边界
- 页面层无需理解新子模块，仍然只依赖 `PipelineCoordinator`
- `dart analyze` 通过
- `flutter test test/features/pipeline/application` 通过
- `flutter test test/controllers/pipeline_controller_test.dart` 通过
- 全量 `flutter test` 通过

## Expected Outcome

完成这一轮后，pipeline 应用层会从“单一超大协调器”演化为：

- 一个薄 coordinator
- 多个清晰的应用层子模块
- 更稳定、更容易继续拆分的结构基础

这会为后续继续收紧 `SettingsCoordinator`、继续拆媒体预览层、或者进一步引入更正式的 use-case 边界打下稳定基础。
