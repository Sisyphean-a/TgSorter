# Telegram 分类恢复链路重构设计

- 日期：2026-04-03
- 设计状态：已与用户确认
- 范围：`lib/app/services`、分类事务模型、分类恢复相关测试

## 1. 目标

本轮重构只处理 `TelegramService` 中“分类 / 恢复 / 事务日志”这一条链路，目标如下：

- 将分类事务状态机从 `TelegramService` 中拆出；
- 将恢复未完成分类事务的策略独立出来；
- 保持 `TelegramGateway` 对外接口不变；
- 保持 `forward -> confirm -> delete` 的业务行为不变；
- 为拆出的协作者增加独立单元测试，降低后续继续拆分 `TelegramService` 的风险。

本轮**不处理**消息分页、预览构建、媒体下载预热等职责；也**不改** UI、控制器和仓储结构。

## 2. 现状问题

当前 `TelegramService` 的分类相关逻辑存在以下问题：

- `classifyMessage()` 同时承担：
  - 解析来源 chat；
  - 创建事务；
  - 写入事务日志；
  - 执行转发确认；
  - 执行删除；
  - 推进事务阶段；
  - 处理失败回写。
- `recoverPendingClassifyOperations()` 同时承担：
  - 遍历未完成事务；
  - 判断恢复策略；
  - 检查源消息是否仍存在；
  - 再次删除源消息；
  - 统计 recovered/manualReview/failed 数量。
- 事务状态推进逻辑散落在 `_buildClassifyTransaction()`、`_recordClassifyTransactionError()`、`_upsertClassifyTransaction()`、`_removeClassifyTransaction()` 等多个私有方法里，外层方法需要知道很多内部细节。

结果是：

- `TelegramService` 变得过大且难测；
- 分类事务规则不能独立演化；
- 后续若要调整恢复策略，必须继续修改大服务类；
- 测试只能围绕整个 `TelegramService` 写，定位问题成本高。

## 3. 方案选型

### 方案 A：只提炼 Journal 辅助类

仅抽出事务的 `build/upsert/remove/error`。

优点：

- 改动最小；
- 风险最低。

缺点：

- 恢复策略仍留在 `TelegramService`；
- 主流程还是知道太多事务细节；
- 收益有限。

### 方案 B：提炼 `ClassifyTransactionCoordinator`（推荐）

新增一个协调器，统一负责：

- 创建事务；
- 推进事务阶段；
- 记录失败；
- 恢复未完成事务。

`TelegramService` 只负责：

- 调用 TDLib 执行转发 / 删除；
- 在关键节点通知协调器推进状态。

优点：

- 收益明显；
- 风险可控；
- 对外接口不变；
- 方便后续继续拆 delivery monitor。

缺点：

- 需要为协调器设计少量回调接口；
- 首轮测试要同时覆盖协调器和原服务。

### 方案 C：一次拆成 Workflow / Journal / DeliveryMonitor 三层

优点：结构最完整。

缺点：

- 首轮变更面过大；
- 回归成本高；
- 不符合当前“小步安全迁移”的目标。

本轮采用**方案 B**。

## 4. 重构后架构

### 4.1 新增模块

新增：`lib/app/services/classify_transaction_coordinator.dart`

职责：

- 创建分类事务；
- 标记 `forwardConfirmed`；
- 标记 `sourceDeleteConfirmed`；
- 记录失败并决定是否进入 `needsManualReview`；
- 执行恢复未完成事务；
- 输出 `ClassifyRecoverySummary`。

### 4.2 保留在 `TelegramService` 的职责

`TelegramService` 继续负责：

- `classifyMessage()` 对外业务入口；
- `undoClassify()` 对外业务入口；
- `_forwardMessagesAndConfirmDelivery()` 及其相关轮询；
- 与 TDLib adapter 的真实通信；
- 消息是否存在的底层读取能力（通过回调提供给协调器）。

### 4.3 协调边界

`TelegramService` 不再自己决定事务如何落库、如何恢复。

新的协作方式：

1. `TelegramService` 解析 `actualSourceChatId`；
2. 调用协调器 `startTransaction(...)`；
3. 执行 `_forwardMessagesAndConfirmDelivery(...)`；
4. 调用协调器 `markForwardConfirmed(...)`；
5. 执行 `deleteMessages`；
6. 调用协调器 `markSourceDeleteConfirmed(...)`；
7. 若中途失败，调用协调器 `recordFailure(...)`。

恢复流程则改为：

- `TelegramService.recoverPendingClassifyOperations()`
  仅委托给协调器；
- 协调器内部通过注入的回调执行：
  - 检查源消息是否存在；
  - 删除源消息。

## 5. 接口设计

### 5.1 协调器构造依赖

`ClassifyTransactionCoordinator` 需要以下依赖：

- `OperationJournalRepository? repository`
- `Future<bool> Function(ClassifyTransactionEntry transaction) anySourceMessageExists`
- `Future<void> Function(ClassifyTransactionEntry transaction) deleteSourceMessages`
- `int Function() nowMs`
- `String Function({required int sourceChatId, required List<int> sourceMessageIds}) buildTransactionId`

说明：

- 这样可以把事务规则与 TDLib 细节解耦；
- 协调器不直接依赖 `TdlibAdapter`；
- 时间和 ID 生成可测试替换；
- `repository == null` 时保持当前“空实现”语义。

### 5.2 对外方法

建议暴露：

- `Future<ClassifyTransactionEntry> startTransaction(...)`
- `Future<ClassifyTransactionEntry> markForwardConfirmed(...)`
- `Future<void> markSourceDeleteConfirmed(...)`
- `Future<void> recordFailure(...)`
- `Future<ClassifyRecoverySummary> recoverPendingTransactions()`

### 5.3 恢复策略规则

保留当前语义：

- `created`
  - 直接转 `needsManualReview`
  - 原因：应用在转发确认前中断，无法判断是否已发送
- `forwardConfirmed`
  - 若源消息还存在，则补一次删除；
  - 删除成功后移除事务；
  - 若源消息已不存在，也直接移除事务；
  - 删除失败则更新 `lastError`，计入 `failedCount`
- `sourceDeleteConfirmed`
  - 直接清理事务，计入 `recoveredCount`
- `needsManualReview`
  - 保持不动，计入 `manualReviewCount`

## 6. 文件变更计划

### 新增文件

- `lib/app/services/classify_transaction_coordinator.dart`
- `test/services/classify_transaction_coordinator_test.dart`

### 修改文件

- `lib/app/services/telegram_service.dart`
- `test/services/telegram_service_test.dart`
- `docs/ARCHITECTURE.md`（若实现完成后补充职责边界说明）

## 7. TDD 实施顺序

### 第一步：先补协调器测试

新增 `test/services/classify_transaction_coordinator_test.dart`，覆盖：

- 创建事务会写入 `created`
- `markForwardConfirmed()` 会更新目标消息和阶段
- `markSourceDeleteConfirmed()` 会删除事务
- `recordFailure()` 在 `created` 阶段会转 `needsManualReview`
- 恢复 `forwardConfirmed` 事务时，会按“源消息存在 / 不存在”分支处理
- 恢复 `needsManualReview` 事务时只统计，不修改状态

### 第二步：最小实现协调器

先让协调器测试全部变绿。

### 第三步：让 `TelegramService` 委托协调器

只改实现，不改 `TelegramGateway` 签名，不改 controller 调用点。

### 第四步：跑现有回归测试

重点回归：

- `classifyMessage does not delete when forward returns empty`
- `classifyMessage waits pending target message to be sent before deleting source`
- `classifyMessage does not delete when pending target message confirmation times out`
- `recoverPendingClassifyOperations retries delete for forwardConfirmed transaction`
- `recoverPendingClassifyOperations marks created transaction as manual review`

## 8. 风险与控制

### 风险 1：恢复语义被意外改变

控制：

- 先补协调器单测；
- 保留现有 `telegram_service_test.dart` 回归测试；
- 不改阶段枚举与仓储结构。

### 风险 2：事务清理时机变化

控制：

- `markSourceDeleteConfirmed()` 仍保持“先落库到 `sourceDeleteConfirmed` 再 remove”；
- 用测试锁住顺序语义。

### 风险 3：协作者反而泄漏更多底层细节

控制：

- 协调器只依赖回调，不直接依赖 TDLib；
- delivery confirm 逻辑明确留在 `TelegramService`，本轮不拆。

## 9. 本轮不做的事

以下内容明确不在本轮范围：

- 拆分 `_forwardMessagesAndConfirmDelivery()`；
- 拆分消息获取 / 分页 / 预览构建；
- 变更 `OperationJournalRepository` 的存储格式；
- 修改控制器和页面层；
- 调整任何 UI 文案。

## 10. 完成标准

满足以下条件才算本轮完成：

- `TelegramService` 中不再持有事务创建 / 恢复 / 失败推进的核心规则；
- 新增协调器测试通过；
- 现有分类与恢复相关服务测试通过；
- `TelegramGateway` 外部接口保持不变；
- 代码职责边界比当前更清晰，后续可以继续拆 delivery monitor。
