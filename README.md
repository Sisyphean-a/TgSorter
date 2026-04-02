# TgSorter

TgSorter 是一个基于 Flutter + TDLib 的 Telegram 消息分流工具。当前目标是从 `Saved Messages` 或指定来源会话中拉取消息，在桌面/移动端界面中逐条浏览并快速分类到目标会话，同时保留可见的错误、日志和重试队列，便于高频人工整理。

## 当前状态

- 运行平台：Flutter，已包含 Android 与 Windows 运行链路。
- 接入方式：仅使用 TDLib，不走 Bot API。
- 应用结构：`BootstrapApp -> GetX DI -> Auth / Pipeline / Settings`。
- 设置体验：设置页已重构为单页分组草稿表单，所有修改统一通过页面底部一次保存。
- 消息浏览：支持分页缓存、前后切换、跳过、批处理、撤销上一步。
- 预览能力：
  - 文本：支持格式化文本与可点击链接。
  - 图片：支持单图与多图相册预览，优先下载预览尺寸。
  - 视频：支持单视频与多视频相册预览，缩略图优先下载，点击后下载原视频并播放。
  - 音频：支持单音频播放；支持“多音频相册”聚合为一个流水线项。
  - 富链接：支持基础网页摘要卡片。

## 文档

- 架构文档：[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 媒体预览现状与方案：[docs/MEDIA_PREVIEW_ANALYSIS.md](docs/MEDIA_PREVIEW_ANALYSIS.md)
- Android TDLib 参数说明：[docs/tdlib-android-params.md](docs/tdlib-android-params.md)

## 技术栈

- Flutter / Dart 3.11
- GetX
- TDLib Dart 插件 `tdlib`
- `shared_preferences`
- `url_launcher`
- `video_player`
- `video_player_media_kit`
- `just_audio`

## 目录概览

```text
lib/
  main.dart
  app/
    app.dart
    bootstrap_app.dart
    bindings.dart
    controllers/
    domain/
    models/
    pages/
    services/
    widgets/
test/
docs/
```

更完整的职责说明见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 启动方式

1. 在项目根目录准备 `.env.local.json`：

```json
{
  "TDLIB_API_ID": "你的_api_id",
  "TDLIB_API_HASH": "你的_api_hash"
}
```

2. 安装依赖：

```bash
flutter pub get
```

3. Android 运行：

```bash
flutter run --dart-define-from-file=.env.local.json
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
- 设置页按“基础流程 / 分类管理 / 连接设置 / 操作与工具”分组，分类、代理、快捷键都先写入草稿，再统一保存。
- 分类操作通过 `forwardMessages -> deleteMessages` 完成，失败时写入日志与重试队列。
- 删除使用原有 `deleteMessages(revoke: true)` 路径。
- 所有 TDLib 业务请求都经由 `TelegramService`，TDLib 生命周期由 `TdlibAdapter` 管理。

## 已知边界

- 安卓端“跳过当前”文案已改为“略过此条”，用于规避第三方跳过工具误判。
- 第三方 TG 客户端的删除显示样式仍受其自身实现影响。
- 现有文档设计稿较多，真正反映当前代码状态的文档以 `README.md`、`docs/ARCHITECTURE.md`、`docs/MEDIA_PREVIEW_ANALYSIS.md` 为准。
