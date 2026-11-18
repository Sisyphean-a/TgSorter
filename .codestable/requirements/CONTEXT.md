# 领域地图

| 范围 | 领域所有权 | 实现包与入口 |
| --- | --- | --- |
| context:message-classification | 消息分类、转发确认、删除及恢复 | `tgsorter`；[规则](contexts/message-classification.md) |

## 工作区语言

- **来源会话**是待处理 Telegram 消息的来源，**目标会话**是用户选择的整理目的地；工作台和配置可以分别指定来源（`lib/app/models/app_settings.dart`）。
- **标签工作台**处理标签追加，与将消息转发到分类目标的操作不同；标签追加去除末尾空白后添加标签，已有完整匹配标签时不重复追加（`lib/app/features/tagging/application/tag_append_service.dart`）。
