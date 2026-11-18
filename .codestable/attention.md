# 项目注意事项

- 先按 [架构索引](architecture/INDEX.md) 和 [领域地图](requirements/CONTEXT.md) 加载目标范围；历史只在追查原因时检索。
- 消息分类涉及远端转发和删除，不要把请求已返回当作投递成功；修改前阅读分类领域规则。
- TDLib 凭据、会话数据及详细 JSON 日志可能包含敏感信息；不要提交本地凭据或泄露日志。
- Android 和 Windows 的 TDLib 宿主差异以各平台实现及测试为准，不从一端推断另一端。
