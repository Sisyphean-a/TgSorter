# Architecture

## Overview

TgSorter 是一个基于 Flutter + GetX + TDLib 的消息分流应用。应用负责启动 TDLib、完成 Telegram 用户授权、从来源会话分页拉取消息、将消息映射成流水线项并在 UI 中展示，随后执行“转发 -> 删除 -> 下一条”的人工分拣流程。当前结构已经完成最终演化：`features/*` 是唯一真实业务入口，跨 feature 的展示资产统一收敛到 `shared/`，旧的 compat/legacy 层已全部移除。

## Stack

| Layer | Technology | Version |
| --- | --- | --- |
| Runtime | Flutter | SDK `^3.11.4` |
| Language | Dart | SDK `^3.11.4` |
| State / Routing | GetX | `^4.7.3` |
| Telegram Client | TDLib plugin | `^1.6.0` |
| Storage | shared_preferences | `^2.5.5` |
| Link Opening | url_launcher | `^6.3.2` |
| Video Playback | video_player | `^2.10.0` |
| Video Backend | video_player_media_kit | `^2.0.0` |
| Audio Playback | just_audio | `^0.10.5` |

## Startup Flow

1. `lib/main.dart`
   - 初始化 Flutter Binding。
   - 调用 `initializeVideoPlayback()` 初始化视频后端。
   - 注册启动期错误写入 `startup_error.log`。
   - 启动 `BootstrapApp`。
2. `lib/app/bootstrap_app.dart`
   - 在 `FutureBuilder` 中执行 `initDependencies()`。
   - 根据初始化状态展示 loading / error / app。
3. `lib/app/bindings.dart` -> `lib/app/core/di/app_bindings.dart`
   - 启动期通过薄转发入口接入模块化 DI。
   - 创建 `SharedPreferences` 仓储、TDLib 传输层、适配器与全局错误控制器。
   - 分模块注册 `settings / auth / pipeline` 依赖。
4. `lib/app/app.dart`
   - 启动 `GetMaterialApp`。
   - 通过 `lib/app/core/routing/app_routes.dart` 注册 `/auth`、`/pipeline`、`/settings`。
   - 在路由层完成页面依赖装配，页面组件仅接收显式构造参数。

## Runtime Architecture

### UI Layer

- `lib/app/features/auth/presentation/auth_page.dart`
  - 登录页面。
- `lib/app/features/pipeline/presentation/pipeline_page.dart`
  - 主流水线容器，组合错误面板与移动端/桌面端布局。
- `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
  - 移动端流水线布局，采用单手快速流与底部操作托盘。
- `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
  - 桌面端流水线布局与快捷键绑定，采用消息工作区 + 操作面板双栏结构。
- `lib/app/features/settings/presentation/settings_page.dart`
  - 单页设置容器，负责草稿态、统一保存和放弃更改。

### Shared Presentation Layer

- `lib/app/shared/presentation/widgets/app_shell.dart`
  - 提供统一页面壳层、背景与最大内容宽度约束。
- `lib/app/shared/presentation/widgets/brand_app_bar.dart`
  - 统一品牌工具栏，承载标题、副标题、状态徽章与全局操作。
- `lib/app/shared/presentation/widgets/status_badge.dart`
  - 用于连接状态、剩余数量、草稿状态等上下文反馈。
- `lib/app/shared/presentation/widgets/app_error_panel.dart`
  - 跨页面显示启动期与运行期错误。
- `lib/app/shared/presentation/widgets/workspace_panel.dart`
  - 桌面端与设置页共享的工作区表面容器。
- `lib/app/shared/presentation/widgets/sticky_action_bar.dart`
  - 设置页固定底部操作栏。
- `lib/app/shared/presentation/widgets/message_viewer_card.dart`
  - 统一消息预览卡片入口，只负责卡片壳层、头部和加载遮罩。
- `lib/app/shared/presentation/widgets/message_preview_content.dart`
  - 按预览类型分发具体内容组件。
- `lib/app/shared/presentation/widgets/message_preview_text.dart`
  - 负责富文本与链接实体渲染。
- `lib/app/shared/presentation/widgets/message_preview_link.dart`
  - 负责链接卡片展示。
- `lib/app/shared/presentation/widgets/message_preview_media.dart`
  - 负责图片、多图、视频和多视频组预览。
- `lib/app/shared/presentation/widgets/message_preview_audio.dart`
  - 负责单音频与多音频轨道列表。
- `lib/app/shared/presentation/widgets/message_preview_helpers.dart`
  - 负责时长、占位态和局部共用预览辅助组件。
- `lib/app/shared/presentation/formatters/pipeline_log_formatter.dart`
  - 设置页复用的分类日志格式化器。

### Application Layer

- `AuthCoordinator`
  - 监听 TDLib 授权状态。
  - 提交手机号、验证码、二步验证密码。
  - 处理代理保存并重试登录。
- `PipelineCoordinator`
  - 管理当前消息、缓存页、上一条/下一条导航、批处理、撤销、失败重试。
  - 协调媒体准备、恢复逻辑、剩余数量刷新与自动拉取。
- `SettingsCoordinator`
  - 同时维护已保存配置与草稿配置。
  - 管理分类目标、来源会话、代理、快捷键、批处理参数等设置。
  - 实现 `PipelineSettingsReader`，向流水线模块暴露稳定的配置读取能力。
- `AppErrorController`
  - 统一收敛启动错误和运行期错误。

### Service Layer

- `TdRawTransport` / `TdClientTransport`
  - 封装 TDLib 原始收发与请求关联。
- `TdlibAdapter`
  - 封装 TDLib 生命周期、鉴权、代理、启动能力探测与请求执行。
- `TelegramService`
  - 业务服务层，负责消息拉取、分类转发编排、预览文件下载启动、撤销和会话查询。
- `MessageHistoryPaginator`
  - 管理消息历史分页、游标推进与全量遍历规则。
- `MediaDownloadCoordinator`
  - 负责媒体预热下载、播放下载与 `downloadFile` 跳过规则。
- `ClassifyTransactionCoordinator`
  - 管理分类事务状态推进、失败记录与未完成事务恢复。
- `SettingsRepository`
  - 基于 `SharedPreferences` 的应用设置持久化。
- `OperationJournalRepository`
  - 分类日志与失败重试队列持久化。

### Composition Boundary

- 页面依赖在 `app_routes.dart` 路由注册处统一装配，页面只负责展示与交互。
- `features/*` 是唯一真实业务入口，不再保留 `controllers/` 或 `pages/` 的兼容导出壳。
- 跨 feature 的可复用展示组件与格式化器统一沉淀到 `shared/presentation/*`。
- `TelegramService` 以 capability-based facade 形式同时实现鉴权、读取、媒体、分类、恢复和会话查询能力接口。
- `SettingsCoordinator` 通过 `PipelineSettingsReader` 向流水线暴露配置契约，避免跨 feature 直接耦合具体实现。

### Domain / Model Layer

- `TdMessageDto`
  - 解析 TDLib 返回的消息 JSON。
  - 当前支持 `messageText`、`messagePhoto`、`messageVideo`、`messageAudio`、`messageVoiceNote`。
- `MessagePreviewBuilder`
  - 负责相册分组、`PipelineMessage` 生成与多媒体预览组装。
  - 作为纯转换组件，为 `TelegramService` 提供消息到预览模型的聚合规则。
- `MessagePreview`
  - UI 预览模型，承载主预览、媒体项列表、音频轨列表与链接卡片。
- `PipelineMessage`
  - 流水线项，承载一个或多个 `messageIds` 与一个 `MessagePreview`。

## Message Pipeline

### Fetch

`PipelineCoordinator.fetchNext()` 会调用 `TelegramService.fetchMessagePage()` 拉取一页消息并缓存。服务层使用 `getChatHistory` 读取来源会话消息，支持最新优先 / 最旧优先两种遍历方向。

### Group

`MessagePreviewBuilder.groupPipelineMessages()` 会对相同 `media_album_id` 的音频、图片、视频消息做聚合，形成单个流水线项。

### Preview

`MessagePreviewBuilder` 会把 TDLib DTO 转成 UI 预览模型：

- 文本：直接显示格式化文本。
- 图片：支持单图与多图相册，优先下载预览尺寸。
- 视频：支持单视频与多视频相册，优先下载缩略图。
- 音频：支持单音频与多音频组。
- 文本链接：支持网页摘要卡片。
- 其他类型：显示兜底文案。

### Action

分类操作通过 `forwardMessages` 把 `PipelineMessage.messageIds` 整体转发到目标会话，再调用 `deleteMessages(revoke: true)` 删除来源消息。撤销则反向转发目标消息并删除目标副本。

## Media Preview Behavior

### Text and Links

- 支持 `url`、`textUrl`、邮箱、电话号码实体。
- 如果 TDLib 返回 `web_page`，会展示基础链接卡片并支持外跳。

### Photos

- `messagePhoto` 会保留多尺寸候选。
- 拉取消息页时优先下载较小预览尺寸。
- UI 渲染优先使用预览尺寸，必要时可继续使用更大尺寸文件。

### Videos

- `messageVideo` 会解析独立 `thumbnail.file` 与 `video.video`。
- 拉取消息页时通过 `MediaDownloadCoordinator` 只启动缩略图下载。
- 用户点击播放后才启动原视频下载与播放器初始化。

### Audio

- 单音频可以边下载边准备播放。
- 多音频相册会聚合为一个流水线项，并在卡片中逐条渲染轨道按钮。
- `prepareMediaPlayback(messageId)` 会通过 `MediaDownloadCoordinator` 按音轨单独下载。

## Current Constraints

1. 图片预览已支持轻量尺寸优先，但还没有单独的全屏原图查看器。
2. 第三方客户端的最终删除显示样式无法完全由本项目控制。
3. 共享组件已经完成目录归位，但更细粒度的 block renderer 拆分仍可继续演化。

## Directory Structure

```text
lib/
  main.dart
  app/
    app.dart
    bootstrap_app.dart
    bindings.dart
    controllers/
      app_error_controller.dart
    core/
      di/
      routing/
    domain/
    features/
      auth/
        application/
        presentation/
      pipeline/
        application/
        presentation/
      settings/
        application/
        domain/
        presentation/
    models/
    services/
    shared/
      presentation/
        formatters/
        widgets/
    theme/
    widgets/
test/
  controllers/
  domain/
  features/
  integration/
  pages/
  services/
  widgets/
docs/
  ARCHITECTURE.md
  MEDIA_PREVIEW_ANALYSIS.md
  plans/
  superpowers/
```

## Configuration

- TDLib 凭证来自 `.env.local.json` 或等价 `--dart-define`。
- 代理、来源会话、分类目标、批处理参数、快捷键都保存在 `SharedPreferences`。
- 设置页中的编辑不会立即落盘，只有页面级保存时才写入 `SharedPreferences` 并在需要时重启 TDLib。
- Windows 需要额外提供 TDLib 动态库及其 OpenSSL 依赖。

## Testing

当前测试主要覆盖：

- TDLib DTO 解析。
- `TelegramService` 业务行为。
- `PipelineCoordinator` 流水线导航与媒体准备逻辑。
- `SettingsCoordinator` 设置草稿态与保存行为。
- 全局主题、品牌工具栏和状态徽章的基础渲染。
- 桌面端工作台与移动端快速流布局。
- `MessageViewerCard` 的视频 / 音频预览状态。
- 消息预览拆分后的文本、链接、媒体和音频行为边界。
- 登录、流水线、设置三条页面主链与集成流程。
