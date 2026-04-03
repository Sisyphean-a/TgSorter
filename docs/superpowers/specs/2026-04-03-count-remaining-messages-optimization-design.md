# countRemainingMessages 定向优化设计

## 背景

当前 `TelegramMessageReader.countRemainingMessages()` 通过
`MessageHistoryPaginator.fetchAllHistoryMessages()` 拉取完整历史消息列表后再取长度。

这会带来两个问题：

1. 长会话下会把整段消息历史保存在内存中
2. 实际需求只是“计数”，不需要保留完整消息对象列表

## 目标

在不改变 `TelegramGateway` 外部契约、不影响分页/预览行为的前提下，
将剩余消息统计改为“分页累计计数”，降低内存占用。

## 非目标

- 不修改 `fetchMessagePage()`
- 不修改 `fetchNextMessage()`
- 不修改 `fetchAllHistoryMessages()` 的现有用途
- 不调整 `PipelineController` 逻辑

## 方案

仅修改 `TelegramMessageReader.countRemainingMessages()`：

- 继续按页请求历史消息
- 继续使用 `cursor` 与 `seenMessageIds` 防重
- 继续保留“游标未推进”保护
- 不再构建完整 `List<TdMessageDto>`
- 改为边遍历边累计 `count`

## 测试策略

- 保持现有 `countRemainingMessages continues across short history pages` 回归测试通过
- 新增一条聚焦测试：跨页重复游标消息不会重复计数
- 跑 `telegram_service_test.dart` 与 `pipeline_controller_test.dart`

## 完成定义

- `countRemainingMessages()` 不再依赖完整历史列表常驻内存
- 现有相关测试通过
- 新增重复游标计数测试通过
