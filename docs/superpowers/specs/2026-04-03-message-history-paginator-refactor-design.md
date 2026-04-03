# Message History Paginator 重构设计

- 日期：2026-04-03
- 设计状态：已与用户口头确认，待用户审阅 spec
- 范围：`lib/app/services`、消息历史分页相关测试

## 1. 目标

本轮只处理 `TelegramService` 中“消息历史分页 / 游标推进 / 全量遍历”相关职责，目标如下：

- 将消息历史读取与分页规则从 `TelegramService` 中拆出；
- 保持 `TelegramGateway` 对外接口不变；
- 保持 `latestFirst` / `oldestFirst` 行为不变；
- 保持现有跨短页补拉、去重游标、全量遍历行为不变；
- 为拆出的分页器增加独立单元测试，为下一轮继续拆预览链路做准备。

本轮**不处理**预览构建、媒体下载预热、相册分组、播放准备逻辑；也**不改** UI、控制器和仓储结构。

## 2. 现状问题

当前 `TelegramService` 同时承担了以下与消息历史相关的职责：

- `_fetchSavedMessagePage()`：根据方向选择分页策略；
- `_fetchSavedMessage()`：获取单条消息入口；
- `_fetchLatestSavedMessagePage()`：处理 latest-first 方向和重复游标过滤；
- `_fetchOldestSavedMessagePage()`：处理 oldest-first 方向和全量回放裁剪；
- `_fetchHistoryPage()`：封装底层 `getChatHistory` 调用；
- `_fetchAllHistoryMessages()`：持续翻页直到历史穷尽；
- `countRemainingMessages()`、`fetchMessagePage()`、`fetchNextMessage()` 直接依赖这些细节。

结果是：

- `TelegramService` 既做业务编排，又做分页基础设施；
- 分页方向、游标和短页补拉规则散落在服务内部，难以单独验证；
- 下一轮若要拆预览构建，`TelegramService` 仍然会被历史逻辑占满上下文；
- 测试只能围绕整个 `TelegramService` 写，难以定位分页规则错误。

## 3. 方案选型

### 方案 A：只提取 `_fetchHistoryPage()`

优点：改动最小。

缺点：

- 仍然保留 latest/oldest 的规则分散在 `TelegramService`；
- 收益很有限；
- 不能真正降低 `fetchMessagePage()` 的复杂度。

### 方案 B：提取 `MessageHistoryPaginator`（推荐）

新增一个分页器，统一负责：

- 获取单页历史；
- latest-first 去重游标规则；
- oldest-first 的全量遍历与裁剪；
- 获取单条消息；
- 获取全量历史。

`TelegramService` 只负责：

- 鉴权；
- 解析 `sourceChatId`；
- 调用分页器拿到 `TdMessageDto`；
- 继续做媒体预热与流水线组装。

优点：

- 收益明显；
- 风险可控；
- 与下一轮“预览链路拆分”天然衔接；
- 不改外部接口。

缺点：

- 需要为分页器设计对 adapter 的依赖边界；
- 现有 `telegram_service_test.dart` 需要保留回归覆盖。

### 方案 C：一次性拆分页器 + 预览构建器

优点：结构更完整。

缺点：

- 本轮变更面过大；
- 无法保持“小步重构”的节奏；
- 回归成本明显上升。

本轮采用**方案 B**。

## 4. 重构后架构

### 4.1 新增模块

新增：`lib/app/services/message_history_paginator.dart`

职责：

- 封装底层 `getChatHistory` 请求；
- 提供 `fetchSavedMessagePage()`；
- 提供 `fetchSavedMessage()`；
- 提供 `fetchAllHistoryMessages()`；
- 实现 `latestFirst` / `oldestFirst` 的方向差异与游标规则。

### 4.2 保留在 `TelegramService` 的职责

`TelegramService` 继续负责：

- `countRemainingMessages()` / `fetchMessagePage()` / `fetchNextMessage()` 对外业务入口；
- 鉴权检查；
- 解析来源 chat（含 Saved Messages）；
- 媒体预热；
- `TdMessageDto -> PipelineMessage` 分组与预览组装。

### 4.3 协作边界

新的协作方式：

1. `TelegramService` 先完成鉴权和 `sourceChatId` 解析；
2. 调用 `MessageHistoryPaginator` 获取 `TdMessageDto`；
3. 触发 `_ensureMediaDownloadsStarted()`；
4. 调用 `_groupPipelineMessages()` 组装 `PipelineMessage`。

这样可以让分页器只关心“如何读消息”，不关心媒体预热和 UI 预览。

## 5. 接口设计

### 5.1 构造依赖

`MessageHistoryPaginator` 依赖：

- `TdlibAdapter adapter`
- `Duration defaultTimeout`
- `int historyBatchSize`

说明：

- 直接使用 adapter 发底层请求，避免让 `TelegramService` 再中转一层；
- `defaultTimeout` 和 `historyBatchSize` 作为可注入参数，方便测试；
- 不引入新的仓储或 gateway 抽象，保持本轮最小复杂度。

### 5.2 对外方法

建议暴露：

- `Future<TdMessageDto?> fetchSavedMessage({required int chatId, required MessageFetchDirection direction})`
- `Future<List<TdMessageDto>> fetchSavedMessagePage({required int chatId, required MessageFetchDirection direction, required int? fromMessageId, required int limit})`
- `Future<List<TdMessageDto>> fetchAllHistoryMessages(int chatId)`

### 5.3 内部规则

保留当前语义：

- `latestFirst`
  - 调用底层 `getChatHistory`；
  - 若传入 `fromMessageId`，去掉与游标重复的首条消息；
  - 最终按请求 limit 截断。
- `oldestFirst`
  - 通过全量遍历历史得到顺序稳定的 oldest-first 列表；
  - 若传入 `fromMessageId`，从该消息之后继续截取；
  - 最终按请求 limit 截断。
- `fetchAllHistoryMessages`
  - 持续拉取直到空页；
  - 正确推进 `fromMessageId`；
  - 保持 oldest-first 结果顺序稳定。

## 6. 文件变更计划

### 新增文件

- `lib/app/services/message_history_paginator.dart`
- `test/services/message_history_paginator_test.dart`

### 修改文件

- `lib/app/services/telegram_service.dart`
- `test/services/telegram_service_test.dart`
- `docs/ARCHITECTURE.md`（实现完成后补充分页职责边界）

## 7. TDD 实施顺序

### 第一步：先补分页器测试

新增 `test/services/message_history_paginator_test.dart`，覆盖：

- `latestFirst` 去重游标
- `oldestFirst` 保持升序
- `oldestFirst` 跨短页补拉
- `fetchSavedMessage()` 只返回一条
- `fetchAllHistoryMessages()` 正确遍历到结尾

### 第二步：最小实现分页器

先让分页器测试全部变绿。

### 第三步：让 `TelegramService` 委托分页器

只改实现，不改 `TelegramGateway` 签名，不改 controller 调用点。

### 第四步：跑现有回归测试

重点回归：

- `fetchNextMessage for video downloads thumbnail only`
- `fetchMessagePage skips duplicate cursor in latestFirst mode`
- `fetchMessagePage oldestFirst continues across short history pages`
- `countRemainingMessages continues across short history pages`
- 相册消息分组相关测试

## 8. 风险与控制

### 风险 1：oldest-first 顺序被破坏

控制：

- 单独为分页器补 oldest-first 测试；
- 保留 `telegram_service_test.dart` 里原有回归断言。

### 风险 2：latest-first 游标去重行为变化

控制：

- 为“传入 `fromMessageId` 去掉首条重复消息”写独立测试；
- 在服务回归中保留现有断言。

### 风险 3：分页器依赖边界设计过重

控制：

- 本轮只依赖 `TdlibAdapter`，不再新增更多抽象；
- 不把媒体预热、预览构建掺进分页器。

## 9. 本轮不做的事

以下内容明确不在本轮范围：

- 拆分 `_groupPipelineMessages()`；
- 拆分 `_buildPreview()` / `_buildMediaGalleryPreview()`；
- 拆分 `_ensureMediaDownloadsStarted()`；
- 修改控制器和页面层；
- 调整分类事务逻辑。

## 10. 完成标准

满足以下条件才算本轮完成：

- `TelegramService` 中不再持有历史分页核心规则；
- 新增分页器测试通过；
- 现有消息获取相关服务测试通过；
- `TelegramGateway` 外部接口保持不变；
- 下一轮继续拆预览链路时，分页逻辑已经有清晰边界。
