# tgsorter 应用包

## 职责与边界

Flutter 应用通过 TDLib 操作 Telegram，不使用 Bot API。`lib/main.dart`、`lib/app/bootstrap_app.dart` 负责启动，`lib/app/core/di/` 组装依赖和工作台；`lib/app/features/` 按 auth、pipeline、tagging、download、login_alerts、settings、shell、workbench 组织界面、应用逻辑和端口。

`lib/app/services/` 承担 TDLib 适配、Telegram 业务与本地持久化；`TdlibAdapter` 管理 TDLib 生命周期和传输，`TelegramService` 组合业务能力。`lib/app/domain/` 包含消息预览等领域转换，`lib/app/models/` 为共享模型，`lib/app/shared/`、`theme/`、`widgets/` 提供共享展示能力。

## 修改定位

- 分类与恢复：`features/pipeline/application/pipeline_action_service.dart` → `services/telegram_classify_workflow.dart`、`classify_transaction_coordinator.dart`；远端删除安全约束见 [消息分类](../../requirements/contexts/message-classification.md)。
- 预览和下载：`domain/message_preview_builder.dart`、`services/media_download_coordinator.dart`、`features/pipeline/application/`；不同媒体的准备与播放路径不可混同。
- 设置：`features/settings/application/` 与 `services/settings_repository.dart`；身份认证由 `services/tdlib_adapter.dart` 及相关服务承接。连接使用宿主网络（包括系统 VPN），启动时禁用旧版本留在 TDLib 中的内置代理；链接预览兼容性只在实际需要预览时检查，不作为启动前提。
- 原生边界：`android/`、`windows/`；TDLib 动态库定位见 `services/tdlib_library_locator.dart`，运行路径见 `services/tdlib_runtime_paths.dart`。
- 回归测试按同名功能分布在 `test/features/`、`test/services/`，跨层流程见 `test/integration/`。
