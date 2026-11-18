# 消息分类

范围：`tgsorter` 的流水线分类；代码入口 `lib/app/services/telegram_classify_workflow.dart`、`telegram_message_forwarder.dart`、`classify_transaction_coordinator.dart`。

- **分类**先向目标会话转发或复制来源消息，再删除来源消息；一个流水线项可包含多个消息 ID。返回的目标消息 ID 用于后续操作。
- **转发确认**不是仅收到 `forwardMessages` 响应：返回数量必须匹配，待发送消息需收到成功更新；失败或确认超时不得继续删除来源。原因是请求返回不等于消息已经投递。
- **分类事务恢复**：已确认转发但尚未确认删除时，恢复流程检查来源并在必要时继续删除；转发确认前中断或失败无法可靠判断是否已投递，标记人工核查，而不自动重发，以免产生重复消息。
- **撤销分类**先将目标消息复制回来源，再删除目标消息；它不是恢复原消息身份的事务回滚。

验证入口：`test/services/telegram_classify_workflow_test.dart`、`test/services/telegram_message_forwarder_test.dart`、`test/services/classify_transaction_coordinator_test.dart`。
