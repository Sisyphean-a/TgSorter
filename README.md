# TgSorter

TgSorter 是一个基于 Flutter + TDLib 的 Android 工具应用，目标是把 Telegram `Saved Messages` 里的消息按人工点击快速分流到 3 个目标会话，并在分流后立即删除原消息，形成高效率的单条流水线处理。

## 项目理念

- 单向流水线：一次只处理 1 条消息，避免 UI 和状态并发导致误操作。
- TDLib 原生接入：仅使用 TDLib，不走 Bot API。
- 操作可见：遇到 FloodWait、断网、配置缺失时直接报错提示，不做静默降级。
- 迭代优先：先搭建可运行骨架和核心闭环，再逐步完善更多消息类型和体验细节。

## 当前已实现

- Flutter Android 项目骨架。
- TDLib 低层传输层：
  - `tdCreate/tdSend/tdReceive` 轮询；
  - 通过 `@extra` 做请求-响应关联；
  - 提供授权状态/连接状态更新流。
- 授权流程（基础版）：
  - `authorizationStateWaitPhoneNumber` 输入手机号；
  - `authorizationStateWaitCode` 输入验证码；
  - `authorizationStateReady` 自动进入主流水线页面。
- 流水线核心动作：
  - 从 `Saved Messages` 拉取 1 条消息；
  - 支持文本 `MessageText` 与图片 `MessagePhoto` 的基础预览；
  - 点击分类按钮后执行 `forwardMessages -> deleteMessages(revoke: true)`；
  - 成功后自动拉取下一条。
- 设置页：
  - 3 个分类按钮名称可配置；
  - 3 个目标 `Chat ID` 可配置；
  - 使用 `shared_preferences` 持久化。
- 异常与边界：
  - `420 FloodWait` 解析并提示等待秒数；
  - 连接状态非 `Ready` 时禁用分类按钮；
  - 不支持消息类型显示兜底文案但允许继续分类。

## 技术栈

- Flutter / Dart
- GetX（状态管理与路由）
- tdlib（TDLib Dart 插件）
- shared_preferences（本地配置存储）

## 目录结构

```text
lib/
  app/
    app.dart
    bindings.dart
    controllers/
      auth_controller.dart
      pipeline_controller.dart
      settings_controller.dart
    domain/
      flood_wait.dart
      message_preview_mapper.dart
    models/
      app_settings.dart
      category_config.dart
      pipeline_message.dart
    pages/
      auth_page.dart
      pipeline_page.dart
      settings_page.dart
    services/
      settings_repository.dart
      td_client_transport.dart
      tdlib_credentials.dart
      telegram_service.dart
    widgets/
      message_viewer_card.dart
  main.dart

test/
  domain/
    flood_wait_test.dart
    message_preview_mapper_test.dart
```

## 运行方式

1. 准备 Telegram 开发者凭据（`api_id` / `api_hash`）。
2. 在项目根目录执行：

```bash
flutter pub get
flutter run \
  --dart-define=TDLIB_API_ID=你的_api_id \
  --dart-define=TDLIB_API_HASH=你的_api_hash
```

## 使用说明

1. 首次进入登录页，输入手机号并提交。
2. 收到验证码后输入并提交。
3. 登录完成后进入主界面：
   - 上半区查看当前待分类消息；
   - 下半区点击“分类 A/B/C”。
4. 若未配置分类目标，进入设置页填写对应 `Chat ID`。

## 注意事项

- 目前目标平台是 Android。
- 项目严格依赖 TDLib，本地需可正常加载插件。
- 请不要把 `api_hash` 写进源码，使用 `--dart-define` 注入。

## TODO（后续对话可直接接续）

- [ ] 完成 Android 侧 TDLib 运行参数细化（目录、设备信息、日志级别等）并补充文档。
- [ ] 支持 `authorizationStateWaitPassword`（两步验证密码）流程。
- [ ] 在图片预览中补齐文件下载流程（当本地文件不存在时主动 `downloadFile`）。
- [ ] 增加消息拉取方向配置（最新优先 / 最旧优先）。
- [ ] 增加“跳过当前消息”与“撤销上一步”能力。
- [ ] 增加批处理模式（N 条连续处理）并配套节流策略。
- [ ] 增加分类操作日志（本地持久化）与失败重试队列。
- [ ] 增加更完整的异常分级（网络、鉴权、权限、TDLib 错误码）。
- [ ] 增加控制器与服务层单元测试（流水线顺序、异常路径、状态流）。
- [ ] 增加集成测试，验证 Auth->Pipeline 全链路。
