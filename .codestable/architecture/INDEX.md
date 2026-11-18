# 架构索引

本仓库是单个 Flutter/Dart 包 `tgsorter`（`pubspec.yaml`），Android 和 Windows 是该包的平台宿主，不是独立业务包。

| 范围 | 入口与归属 | 领域 |
| --- | --- | --- |
| workspace / package:tgsorter | [应用架构](packages/tgsorter.md)：`lib/main.dart`、`lib/app/`；平台 `android/`、`windows/`；测试 `test/` | [领域地图](../requirements/CONTEXT.md) |
| 消息分类、恢复 | `lib/app/features/pipeline/`、`lib/app/services/telegram_classify_workflow.dart` | [消息分类](../requirements/contexts/message-classification.md) |
| 标签工作台 | `lib/app/features/tagging/`、`lib/app/services/telegram_tagging_service.dart` | [领域地图](../requirements/CONTEXT.md) |
| 设置与连接 | `lib/app/features/settings/`、`lib/app/services/settings_repository.dart`、`lib/app/services/tdlib_adapter.dart` | 工作区 |

运行和环境准备见根目录 [README](../../README.md)，Android TDLib 参数见 [说明](../../docs/tdlib-android-params.md)。
