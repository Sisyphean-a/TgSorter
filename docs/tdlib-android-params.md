# Android TDLib 运行参数说明

TDLib 启动时由 `lib/app/services/tdlib_adapter.dart` 配置参数，运行目录由 `lib/app/services/tdlib_runtime_paths.dart` 创建。参数也适用于使用同一适配器的其他宿主；平台动态库加载另见 `tdlib_library_locator.dart`。

- 数据库和文件目录分别为应用支持目录下的 `tgsorter/tdlib/db`、`tgsorter/tdlib/files`。
- 启用文件、会话信息和消息数据库及存储优化；不启用秘密聊天。
- 使用正式数据中心，`systemLanguageCode` 为 `zh-hans`，`deviceModel` 为 `Flutter`，`systemVersion` 为 `unknown`，`applicationVersion` 以适配器当前配置为准。
- API ID 和 API Hash 的准备方式见 [README](../README.md#启动方式)。
- 启动失败会清理传输并向调用方报告错误，不静默降级。

参数的完整当前值以 `TdlibAdapter._setTdlibParameters` 为准。

## 16 KB 预览包（Android arm64）

`stable` 仍是默认变体。预览包的应用 ID 为 `com.example.tgsorter.tdlibpreview`，与稳定包并存，各自有独立的登录、数据库和设置。预览包缺少新版原生库时构建会失败，不会使用稳定包的旧库。

1. 在 Linux/WSL x86_64 安装 C/C++ 编译器、make、CMake、Ninja、gperf、Perl、Python 3 和 curl。准备 **Linux 版 NDK r28c**，将 `ANDROID_NDK_HOME` 指向解压目录；不能使用 Windows 版 NDK。
2. 在 Linux/WSL 的仓库根目录构建原生库。脚本下载并校验固定版本的官方 TDLib 和 OpenSSL 源码，产物写入 `build/tdlib-preview/`。若执行了 `flutter clean`，需重新准备原生库。

   ```bash
   bash tool/build_tdlib_preview.sh
   ```

   没有 Linux 构建环境时，可在 GitHub Actions 使用 `TDLib Android Preview Native`。预览分支 `feat/tdlib-16k-preview` 推送构建脚本或工作流变更时会自动运行；工作流进入默认分支后也可手动运行。将 `tdlib-preview-arm64` 产物解压到 `build/tdlib-preview/`（保留 `jniLibs/` 与 `notices/` 目录）。

3. 回到 Flutter 所在环境打包、校验。若 `zipalign` 不在 PATH，传入 Android SDK Build Tools 中的完整路径。

   ```bash
   flutter build apk --debug --flavor tdlibPreview --target-platform android-arm64 --dart-define-from-file=.env.local.json
   python tool/check_android_16k.py build/app/outputs/flutter-apk/app-tdlibpreview-debug.apk --zipalign /path/to/zipalign
   adb install -r build/app/outputs/flutter-apk/app-tdlibpreview-debug.apk
   ```

4. 在预览包中单独登录，验证登录、拉消息和媒体后再考虑稳定版迁移。预览包不能用来证明旧会话覆盖升级的数据兼容性。
