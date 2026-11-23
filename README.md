# TgSorter

TgSorter 是一个基于 Flutter + TDLib 的 Telegram 消息分流工具。当前目标是从 `Saved Messages` 或指定来源会话中拉取消息，在桌面/移动端界面中逐条浏览并快速分类到目标会话，同时保留可见的错误、日志和重试队列，便于高频人工整理。

## 当前状态

- 运行平台：Flutter，已包含 Android 与 Windows 运行链路。
- 接入方式：仅使用 TDLib，不走 Bot API。
- 应用结构：`BootstrapApp -> GetX DI -> Auth / Pipeline / Settings`。
- 界面系统：已建立统一暗色品牌主题、品牌工具栏、状态胶囊与工作区面板。
- 设置体验：设置页已重构为单页分组草稿表单，所有修改统一通过页面底部一次保存。
- 工作台体验：桌面端为双栏工作台，移动端为单手快速流，分类操作和次级动作已分层。
- 消息预览结构：第二轮已按文本链接、媒体、音频和辅助组件拆分，便于继续维护与扩展。
- **会话去重**：从主导航选择会话，按相同的 Telegram 文件标识查找照片、视频、音频和语音副本，扫描不下载媒体。不同标识的重新上传不会归为一组。预览视频可手动生成 2、4 或 6 张时间缩略图，每次最多请求 12 MiB 分段数据。每组选一份保留，再确认删除其余消息；删除不可撤销。
- 消息浏览：支持分页缓存、前后切换、跳过、批处理、撤销上一步。
- 预览能力：
  - 文本：支持格式化文本与可点击链接。
  - 图片：支持单图与多图相册预览，优先下载预览尺寸。
  - 视频：支持单视频与多视频相册预览，缩略图优先下载，点击后下载原视频并播放。
  - 音频：支持单音频播放；支持“多音频相册”聚合为一个流水线项。
  - 富链接：支持基础网页摘要卡片。

## 文档

- 项目架构与开发定位：[.codestable/architecture/INDEX.md](.codestable/architecture/INDEX.md)
- Android TDLib 参数说明：[docs/tdlib-android-params.md](docs/tdlib-android-params.md)

## 技术栈

- Flutter 3.50+（使用其自带的 Dart SDK）
- GetX
- TDLib Dart 插件 `tdlib`
- `shared_preferences`
- `url_launcher`
- `video_player`（Android 使用 Media3 ExoPlayer，未缓存视频通过 TDLib 按段读取）
- `video_player_media_kit`（Windows）
- `just_audio`

## 目录概览

```text
lib/
  main.dart
  app/
    app.dart
    bootstrap_app.dart
    core/
      di/
      routing/
    domain/
    features/
      auth/
      pipeline/
      settings/
    models/
    services/
    shared/
    theme/
    widgets/
test/
  app/
  controllers/
  domain/
  features/
  integration/
  models/
  pages/
  services/
  shared/
  widgets/
docs/
```

更完整的职责说明见 [架构索引](.codestable/architecture/INDEX.md)。

## 启动方式

1. 在项目根目录准备 `.env.local.json`：

```json
{
  "TDLIB_API_ID": "你的_api_id",
  "TDLIB_API_HASH": "你的_api_hash",
  "TD_LOG_DETAIL": "verbose"
}
```

`TD_LOG_DETAIL` 支持两个值：

- `summary`：默认摘要模式，只打印事件类型和少量关键字段。
- `verbose`：打印完整 TDLib request / response / update 原始 JSON，便于排查预览、生命周期和协议兼容问题。

2. 从锁文件安装依赖。若已配置 Pub 镜像，先将当前终端的 `PUB_HOSTED_URL` 设为 `https://pub.dev`，与锁文件一致（PowerShell 使用 `$env:PUB_HOSTED_URL = "https://pub.dev"`）。

```bash
flutter pub get --enforce-lockfile
```

3. Android：准备 JDK 17 或 21 和 Android SDK Platform 36（构建所需 NDK 等组件可由 Gradle 下载）。使用项目自带的 Gradle Wrapper，不需要另装 Gradle。首次构建会下载构建工具和依赖，不要跳过 Flutter 的版本检查。

```bash
# 连手机运行 Debug 版
flutter run --no-pub --dart-define-from-file=.env.local.json

# 只打包，不需要接手机
flutter build apk --release --no-pub --target-platform android-arm64 --dart-define-from-file=.env.local.json
```

默认 APK 使用已验证的官方 TDLib，输出为 `build/app/outputs/flutter-apk/app-release.apk`。原生库构建和 16 KB 检查见 [Android TDLib 参数说明](docs/tdlib-android-params.md#16-kb-android-原生库arm64)。当前 Release 使用调试签名，仅供自测。如果 Windows 在解析依赖后提示插件符号链接不可用，请在 Windows 设置启用开发人员模式。

若 Release 长时间停在 `minifyReleaseWithR8`，可在当前 PowerShell 窗口显式选择系统安装的 JDK 21，再执行打包命令（将示例路径替换为实际路径）：

```powershell
$env:GRADLE_OPTS += ' -Dorg.gradle.java.home="C:/path/to/jdk-21"'
```

4. Windows 运行前需要额外准备 TDLib 动态库：
   - `windows/tdjson.dll`
   - `windows/libssl-3-x64.dll`
   - `windows/libcrypto-3-x64.dll`
   - `windows/zlib1.dll`

也可以通过环境变量指定 TDLib DLL：

```powershell
$env:TDLIB_DLL_PATH="D:\\path\\to\\tdjson.dll"
```

## 关键行为

- 启动时先初始化视频播放后端，再执行依赖注入与 TDLib 启动。
- 登录流程覆盖手机号、验证码、二步验证密码。
- 流水线页会监听 TDLib 授权状态与连接状态，自动拉取首批消息。
- 全局界面统一复用 `AppTheme`、`AppShell` 和状态徽章组件；登录页继续使用 `BrandAppBar`，流水线与设置页使用各自的紧凑 app bar。
- 桌面端流水线采用“左侧消息工作区 + 右侧操作面板”的双栏结构。
- 移动端流水线将主分类按钮固定在底部操作托盘，辅助动作降级到次级区。
- 分类等可编辑设置先写入草稿，再统一保存。TgSorter 不提供内置代理；手机端如需 VPN，请在系统 VPN 的分应用规则中纳入 TgSorter。
- 分类操作通过 `forwardMessages -> deleteMessages` 完成，失败时写入日志与重试队列。
- 删除使用原有 `deleteMessages(revoke: true)` 路径。
- 所有 TDLib 业务请求都经由 `TelegramService`，TDLib 生命周期由 `TdlibAdapter` 管理。

## 已知边界

- 安卓端“跳过当前”文案已改为“略过此条”，用于规避第三方跳过工具误判。
- 第三方 TG 客户端的删除显示样式仍受其自身实现影响。
- 旧设计与实施计划可从 Git 历史查阅；当前架构及领域规则以代码和 `.codestable/` 为准。
