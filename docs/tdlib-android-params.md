# Android TDLib 运行参数说明

TDLib 启动时由 `lib/app/services/tdlib_adapter.dart` 配置参数，运行目录由 `lib/app/services/tdlib_runtime_paths.dart` 创建。参数也适用于使用同一适配器的其他宿主；平台动态库加载另见 `tdlib_library_locator.dart`。

- 数据库和文件目录分别为应用支持目录下的 `tgsorter/tdlib/db`、`tgsorter/tdlib/files`。
- 启用文件、会话信息和消息数据库及存储优化；不启用秘密聊天。
- 使用正式数据中心，`systemLanguageCode` 为 `zh-hans`，`deviceModel` 为 `Flutter`，`systemVersion` 为 `unknown`，`applicationVersion` 以适配器当前配置为准。
- API ID 和 API Hash 的准备方式见 [README](../README.md#启动方式)。
- 启动失败会清理传输并向调用方报告错误，不静默降级。

参数的完整当前值以 `TdlibAdapter._setTdlibParameters` 为准。

## 16 KB Android 原生库（arm64）

Android 主包使用已验证的官方 TDLib，并沿用试用版的应用 ID `com.example.tgsorter.tdlibpreview`。使用相同签名覆盖安装可保留登录和设置。仓库已包含 `android/tdlib/` 下的原生库和许可证，常规 Flutter 构建直接复用。只有 TDLib、OpenSSL、NDK、目标架构或原生构建参数变化时才需重编译。

1. 在 Linux/WSL x86_64 安装 C/C++ 编译器、make、CMake、Ninja、gperf、Perl、Python 3 和 curl。准备 **Linux 版 NDK r28c**，将 `ANDROID_NDK_HOME` 指向解压目录；不能使用 Windows 版 NDK。
2. 需要重编译时，在 Linux/WSL 的仓库根目录运行脚本。脚本会校验固定版本的官方 TDLib 和 OpenSSL 源码，并将产物写入 `android/tdlib/`。

   ```bash
   bash tool/build_tdlib_android.sh
   ```

   没有 Linux 构建环境时，可在 GitHub Actions 使用 `TDLib Android Native`。手动运行工作流后，将 `tdlib-android-arm64` 产物解压到 `android/tdlib/`，保留 `jniLibs/` 与 `notices/` 目录。

3. 回到 Flutter 所在环境打包、校验。若 `zipalign` 不在 PATH，传入 Android SDK Build Tools 中的完整路径。

   ```bash
   flutter build apk --release --target-platform android-arm64 --dart-define-from-file=.env.local.json
   python tool/check_android_16k.py build/app/outputs/flutter-apk/app-release.apk --zipalign /path/to/zipalign
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
