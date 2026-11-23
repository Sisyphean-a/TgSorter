# tgsorter 应用包

## 职责与边界

Flutter 应用通过 TDLib 操作 Telegram，不使用 Bot API。`lib/main.dart`、`lib/app/bootstrap_app.dart` 负责启动，`lib/app/core/di/` 组装依赖和工作台；`lib/app/features/` 按 auth、pipeline、tagging、download、dedup、login_alerts、settings、shell、workbench 组织界面、应用逻辑和端口。

`lib/app/services/` 承担 TDLib 适配、Telegram 业务与本地持久化；`TdlibAdapter` 管理 TDLib 生命周期和传输，`TelegramService` 组合业务能力。`lib/app/domain/` 包含消息预览等领域转换，`lib/app/models/` 为共享模型，`lib/app/shared/`、`theme/`、`widgets/` 提供共享展示能力。

界面组件使用官方独立包 `material_ui`。`lib/app/app.dart` 的 `MaterialApp` 与 `lib/app/core/routing/` 负责主题和认证路由；GetX 保留用于依赖注入与响应式状态，不再负责应用路由或提示条。旧版 GetX 的 `GetMaterialApp` 与独立 Material 包的主题类型不兼容。

## 修改定位

- 分类与恢复：`features/pipeline/application/pipeline_action_service.dart` → `services/telegram_classify_workflow.dart`、`classify_transaction_coordinator.dart`；远端删除安全约束见 [消息分类](../../requirements/contexts/message-classification.md)。
- 预览和下载：`domain/message_preview_builder.dart`、`services/media_download_coordinator.dart`、`features/pipeline/application/`；不同媒体的准备与播放路径不可混同。去重抽帧由 `services/td_video_thumbnail_preview.dart` 使用带总量约束的 `TdVideoStream`：Android 走系统取帧，Windows 走既有 libmpv。识别与流量契约见 [媒体去重](../../requirements/contexts/media-dedup.md)。
- 设置：`features/settings/application/` 与 `services/settings_repository.dart`；身份认证由 `services/tdlib_adapter.dart` 及相关服务承接。连接使用宿主网络（包括系统 VPN），启动时禁用旧版本留在 TDLib 中的内置代理；链接预览兼容性只在实际需要预览时检查，不作为启动前提。
- 原生边界：`android/`、`windows/`；TDLib 动态库定位见 `services/tdlib_library_locator.dart`，运行路径见 `services/tdlib_runtime_paths.dart`。
- Android 构建使用 AGP 的内置 Kotlin 和新版 DSL；`android/build.gradle.kts` 只适配仍使用旧 Manifest 包名和过低编译 SDK 的 `:tdlib`。升级 TDLib 插件时先检查能否删除这段适配，不将其扩展为全局插件规则。
- Android 使用已通过真机验证的官方 TDLib 原生库，固定源码提交并检查 16 KB ELF/APK 对齐；Dart 通过自有 JSON FFI 调用，JSON 差异集中在 `services/tdlib_modern_wire.dart`。应用 ID 沿用 `com.example.tgsorter.tdlibpreview`，以支持同签名更新并保留新版用户数据。原生产物纳入 `android/tdlib/`，常规构建直接复用。构建入口见 [Android TDLib 参数说明](../../../docs/tdlib-android-params.md#16-kb-android-原生库arm64)。
- 回归测试按同名功能分布在 `test/features/`、`test/services/`，跨层流程见 `test/integration/`。
