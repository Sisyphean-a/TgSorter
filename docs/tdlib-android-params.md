# Android TDLib 运行参数说明

TDLib 启动时由 `lib/app/services/tdlib_adapter.dart` 配置参数，运行目录由 `lib/app/services/tdlib_runtime_paths.dart` 创建。参数也适用于使用同一适配器的其他宿主；平台动态库加载另见 `tdlib_library_locator.dart`。

- 数据库和文件目录分别为应用支持目录下的 `tgsorter/tdlib/db`、`tgsorter/tdlib/files`。
- 启用文件、会话信息和消息数据库及存储优化；不启用秘密聊天。
- 使用正式数据中心，`systemLanguageCode` 为 `zh-hans`，`deviceModel` 为 `Flutter`，`systemVersion` 为 `unknown`，`applicationVersion` 为 `1.0.0`。
- API ID 和 API Hash 的准备方式见 [README](../README.md#启动方式)。
- 启动失败会清理传输并向调用方报告错误，不静默降级。

参数的完整当前值以 `TdlibAdapter._setTdlibParameters` 为准。
