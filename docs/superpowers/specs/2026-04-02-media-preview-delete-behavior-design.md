# Media Preview And Delete Behavior Design

## 背景

当前项目已经支持单文本、单图片、单视频、单音频，以及多音频相册的聚合展示，但整体消息预览模型仍是“单主体媒体 + 音频特判”的结构。这导致多图片、多视频、富链接和图片轻量预览都无法以统一方式接入。同时，安卓端“跳过当前”按钮文案会被外部跳过类无障碍工具误识别，触发连续误操作；分类后的删除效果也与 Telegram 官方客户端存在视觉和语义差异。

本轮设计目标是一次性解决这三个问题，并保持当前分类流程可用：

1. 重构媒体预览链路，统一支持多图片、多视频、多音频、富链接和图片预览图策略。
2. 消除安卓端因“跳过”文案导致的误触发。
3. 将删除行为调整为“优先贴近官方客户端，失败时自动回退到现有逻辑”，不暴露设置开关，不牺牲现有可分类能力。

## 目标

- 一个流水线项可以承载多个媒体附件，而不是只有一个主媒体。
- 多图片、多视频与多音频一样，能够整体展示、整体分类、整体删除。
- 富链接能以卡片形式展示基本信息。
- 图片支持“先预览尺寸、后原图”的按需下载策略。
- 安卓界面不再出现包含“跳过”字样的可点击控件或快捷键说明。
- 删除行为优先采用更接近官方客户端结果的路径；失败时明确在服务层回退，不影响用户操作。

## 非目标

- 本轮不引入用户侧可配置的删除策略开关。
- 本轮不实现完整图片查看器或复杂手势浏览，只提供必要的预览与按需下载能力。
- 本轮不新增静默 fallback 或伪成功路径，所有异常仍然要显式暴露。

## 方案对比

### 方案 A：继续在现有 `MessagePreview` 上加字段和特判

优点：

- 局部改动看起来较小。

缺点：

- 会继续堆积 `if photo / if video / if audio / if link` 分支。
- 多图、多视频、富链接会产生更多专用字段。
- 控制器和服务层要继续围绕“单主媒体”假设补丁。

结论：

- 不采用。

### 方案 B：统一重构为“消息组 + 预览块 + 媒体项”

优点：

- 可以自然表达单图、多图、单视频、多视频、音频列表和富链接卡片。
- 服务层、控制器、UI 层都能围绕统一协议工作。
- 后续扩展文档、文件、投票等类型时不必继续改基本结构。

缺点：

- 影响范围大，需要同步更新 DTO、映射、控制器、组件和测试。

结论：

- 采用。

## 架构设计

### 1. 统一预览模型

把当前 `PipelineMessage -> MessagePreview` 的单体结构重构为：

- `PipelineMessage`
  - 保留 `id`、`messageIds`、`sourceChatId`
  - `preview` 改为消息组级别预览
- `PreviewBlock`
  - `text`
  - `mediaGallery`
  - `audioPlaylist`
  - `linkCard`
  - `unsupported`
- `MediaItem`
  - `messageId`
  - `kind(photo/video)`
  - `previewLocalPath`
  - `fullLocalPath`
  - `previewRemoteFileId`
  - `fullRemoteFileId`
  - `durationSeconds`
  - `caption`

这样可以保证所有媒体类型都以列表条目形式表达，而不是继续塞进若干单独字段。

### 2. DTO 与映射策略

#### 图片

当前 `messagePhoto` 只取 `photo.sizes.last`，需要改成保留多个尺寸候选，并在领域层选出：

- `previewCandidate`
- `fullCandidate`

默认预览下载使用较小尺寸，点击后再下载较大尺寸或原图。

#### 视频

保留现有“缩略图 + 原视频文件”双路径结构，但统一映射为 `MediaItem(video)`，不再通过单独字段挂在 `MessagePreview` 上。

#### 音频

把现有 `audioTracks` 特判改成通用 `audioPlaylist` block，保留按轨道单独下载的能力。

#### 富链接

补充 `link_preview` / `web_page` 相关 DTO，如果 TDLib 响应里存在链接摘要信息，则映射为 `linkCard` block；如果缺字段，则只保留普通可点击文本，不做假卡片。

### 3. 消息分组策略

`TelegramService._groupPipelineMessages()` 从“仅聚合多音频相册”改为：

1. 按 `media_album_id` 聚合消息。
2. 相册内不同内容类型统一映射为一组预览块。
3. 非相册消息仍然构成单项流水线消息。

分类、删除、撤销始终基于整组 `messageIds`。

### 4. 媒体下载与刷新策略

`PipelineController.prepareCurrentMedia([messageId])` 改成按媒体项维度触发，例如：

- `prepareMediaItem(messageId, resourceKind)`

控制器不再通过 `preview.localVideoPath == null` 这类单字段判断刷新，而是根据当前组内 `MediaItem` 的资源状态决定：

- 是否还需要预览图刷新
- 是否还需要原文件刷新

### 5. UI 组件拆分

`MessageViewerCard` 只保留容器职责，具体渲染拆成：

- `preview_block_renderer.dart`
- `text_block.dart`
- `media_gallery_block.dart`
- `audio_playlist_block.dart`
- `link_card_block.dart`

这样可以降低单文件复杂度，并满足当前代码质量约束。

### 6. 安卓“跳过”误判规避

问题根因不是代码主动调用 `skipCurrent()`，而是界面存在带“跳过”字样的按钮和快捷键文案，被外部无障碍跳过工具误识别。

处理策略：

- 所有用户可见“跳过当前”统一改名，例如“略过此条”。
- 快捷键面板中的 `ShortcutAction.skipCurrent` 文案同步改名。
- 排查按钮 tooltip / semantics / text label，确保不再保留“跳过”字样。

不修改业务逻辑本身，避免为了适配第三方跳过工具而引入额外防御逻辑。

### 7. 删除行为策略

当前实现为：

- `forwardMessages`
- `deleteMessages(revoke: true)`

用户观察到第三方客户端里仍有淡化残影，说明当前路径虽然已删除，但删除表现与官方客户端可能存在差异。

设计要求：

- 服务层增加“官方优先删除路径”尝试。
- 如果新路径验证成功，则使用新路径。
- 如果新路径失败、返回异常、或在 TDLib 运行时不兼容，则自动回退到现有 `deleteMessages(revoke: true)` 路径。

回退策略只存在于服务层内部，不暴露为用户设置项。

## 错误处理

- 所有新路径失败都必须抛出真实异常，由服务层决定是否触发回退。
- 回退发生时不静默吞错，至少应记录调试日志，便于后续确认真实失败点。
- 如果最终连旧路径也失败，则延续当前错误上报链路，由 `PipelineController` / `AppErrorController` 向用户提示。

## 测试设计

### 服务层

- 多图片相册聚合成单个 `PipelineMessage`
- 多视频相册聚合成单个 `PipelineMessage`
- 图片优先下载预览尺寸而非原图
- 删除链路优先走新策略，失败时回退旧策略

### 控制器层

- 媒体项下载后刷新组内状态
- 多媒体组分类时保持完整 `messageIds`
- 删除回退场景仍能完成分类

### 组件层

- 多图图库渲染
- 多视频列表渲染
- 音频播放列表渲染
- 富链接卡片渲染
- 安卓“略过此条”文案替换回归

## 实施顺序

1. 先写失败测试，锁定多图片、多视频、富链接和删除回退行为。
2. 扩展 DTO 和领域模型。
3. 重写服务层分组与删除逻辑。
4. 重写控制器媒体准备逻辑。
5. 拆分并重构消息预览 UI。
6. 更新文档与回归测试。
