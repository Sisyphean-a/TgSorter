# 转发确认显式成功设计

- 日期：2026-04-09
- 状态：已确认
- 范围：`lib/app/services`、TD 更新解析、转发确认测试

## 1. 背景

当前分类链路在 `forwardMessages` 返回 `messageSendingStatePending` 时，会持续使用返回的 `message.id` 调用 `getMessage(targetChatId, messageId)` 做轮询确认。

在真实环境中，TDLib 可能先返回处于 pending 的消息对象，后续再通过发送结果更新把临时消息 ID 替换为最终消息 ID。现有实现没有消费这些更新，只会持续查询旧 ID，导致出现以下现象：

- Telegram 客户端中转发已经成功；
- 应用内确认逻辑持续收到 `getMessage(...)=404 Not Found`；
- 超时后中止删除源消息，并抛出“发送状态确认超时”。

## 2. 目标

本次调整的目标如下：

- 修复“转发成功但确认失败”的根因；
- 将源消息删除条件收紧为“收到 TDLib 的显式成功确认”；
- 在弱网或更新缺失场景下，宁可保守地不删源消息，也不允许误判成功后删除源消息；
- 保持对外 `TelegramService` / `ClassifyGateway` 契约不变。

## 3. 非目标

本次不做以下内容：

- 不引入“扫描目标群最后一条消息”之类启发式成功判断；
- 不修改 UI 流程与用户操作入口；
- 不改事务日志存储结构；
- 不扩展为通用消息同步框架，只覆盖当前分类转发链路所需的发送确认。

## 4. 方案选型

### 方案 A：继续使用 `getMessage(oldId)` 轮询

优点：

- 改动最小。

缺点：

- 无法处理临时 ID 到最终 ID 的切换；
- 与本次线上故障根因相同；
- 弱网下会持续出现“实际成功、确认失败”。

不采用。

### 方案 B：扫描目标 chat 最近消息做内容匹配

优点：

- 不依赖发送结果 update。

缺点：

- 本质是启发式；
- 容易受群内其他消息、相似内容、媒体组等影响；
- 不适合作为删除源消息的安全前提。

不采用。

### 方案 C：基于 TDLib 发送结果 update 做显式确认

核心规则：

- `forwardMessages` 返回无 `sending_state` 的消息时，视为立即成功；
- 返回 `pending` 时，等待：
  - `updateMessageSendSucceeded`
  - `updateMessageSendFailed`
- 使用 `old_message_id` 关联 pending 消息，收到 succeeded 后记录最终 `message.id`；
- 超时、断流、未收到成功 update 时，一律不删源消息。

优点：

- 与 TDLib 模型一致；
- 能显式处理临时 ID 到最终 ID 的映射；
- 最符合“避免误删”的安全目标。

采用本方案。

## 5. 设计细节

### 5.1 新增发送结果事件模型

在 TD 原始 update 解析层新增消息发送结果事件，至少覆盖：

- `updateMessageSendSucceeded`
- `updateMessageSendFailed`

需要提取的字段包括：

- `chat_id`
- `old_message_id`
- `message.id`
- 失败错误码与错误信息

### 5.2 Adapter 暴露发送结果流

`TdlibAdapter` 目前只向上暴露授权状态和连接状态，需要增加一个消息发送结果流，供业务层等待 pending 消息的完成结果。

要求：

- 只传递结构化结果，不把 TDLib 原始 payload 直接泄露到业务层；
- 不影响现有授权与连接状态更新订阅；
- 支持 raw transport 模式下的 update 分发。

### 5.3 Forwarder 的新确认语义

`TelegramMessageForwarder` 改为两阶段确认：

1. 解析 `forwardMessages` 返回值
2. 对 pending 消息等待显式发送结果

具体规则：

- `sending_state == null`：立即成功
- `messageSendingStateFailed`：立即失败
- 其他 `sending_state`：加入 pending 集合，等待 update

等待逻辑：

- 仅接受同一 `targetChatId` 下、`old_message_id` 命中的 succeeded/failed 事件；
- succeeded：将 pending 项标记成功，并把最终 `message.id` 作为返回值；
- failed：抛出明确错误；
- timeout：抛出超时错误，不删除源消息。

### 5.4 安全边界

删除源消息前必须满足以下条件之一：

- `forwardMessages` 直接返回已 sent 的目标消息；
- 或 pending 消息收到了 `updateMessageSendSucceeded`。

以下情况一律视为“未确认成功”，禁止删除源消息：

- 收到 404 / not found；
- 群里最后一条消息变化；
- 最近消息列表里出现相似内容；
- 连接抖动；
- 超时；
- 未知 update；
- update 丢失。

这意味着在极端弱网下，可能出现“目标群已经有消息，但本地没收到成功确认，因此暂不删除源消息”的保守行为。这是本次设计刻意接受的安全取舍。

## 6. 测试策略

新增或调整测试覆盖以下场景：

- pending 消息收到 `updateMessageSendSucceeded` 后返回最终目标消息 ID；
- pending 消息收到 `updateMessageSendFailed` 后抛错；
- pending 消息仅有 404 / 无关 update 时最终超时；
- 多条转发时可以按 `old_message_id` 正确逐条关联最终 ID；
- 分类工作流在未显式确认成功时不会调用删除；
- 现有“立即成功”路径保持兼容。

## 7. 完成标准

满足以下条件视为完成：

- 复现并覆盖“转发成功但旧 ID 查询 404”的测试场景；
- forwarder 不再依赖 `getMessage(oldId)` 作为成功依据；
- 未收到显式成功确认时，分类链路不会删除源消息；
- 相关服务测试通过。
