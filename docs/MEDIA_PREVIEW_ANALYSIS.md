# 媒体预览现状与重构方案

## 目标问题

你关心的是四类能力：

1. 视频预览是否可用。
2. 音频、图片、视频在“一个 Telegram 消息包含多个附件”时是否能正确展示多个。
3. 富文档，也就是链接卡片，是否支持。
4. 大图是否可以像视频一样先下载轻量预览图，再按需下载原文件。

基于当前代码，结论如下。

## 当前能力结论

| 场景 | 当前状态 | 结论 |
| --- | --- | --- |
| 单视频 | 支持缩略图优先下载，点击后下载原视频并播放 | 可用 |
| 多视频相册 | 已按 `media_album_id` 聚合，并可分页预览 | 可用 |
| 单音频 | 支持按需下载和播放 | 可用 |
| 多音频相册 | 已按 `media_album_id` 聚合，并以音轨列表展示 | 可用 |
| 单图片 | 支持展示，优先下载预览尺寸 | 可用 |
| 多图片相册 | 已按 `media_album_id` 聚合，并可分页预览 | 可用 |
| 富链接 | 支持 `web_page` 摘要卡片与外跳 | 基础可用 |
| 大图轻量预览 | 已优先选择较小图片尺寸作为预览 | 可用 |

## 证据链

### 1. 之前只有多音频被聚合，现在图片和视频相册也已聚合

当前 `TelegramService._groupPipelineMessages()` 会对同一 `media_album_id` 的音频、图片、视频进行聚合。

### 2. 预览模型已扩展，但仍是兼容过渡结构

`MessagePreview` 除了历史上的单体字段外，已经补入：

- `mediaItems`
- `audioTracks`
- `linkCard`

这已经能支撑多图、多视频和富链接，但还没有完全演进到独立 `PreviewBlock` 子组件架构。

### 3. 图片已具备预览尺寸优先链路

`TdMessageDto._parsePhotoContent()` 现在会保留多尺寸，并把最小尺寸作为预览下载候选。

### 4. 富链接已支持基础卡片

`messageText.web_page` 现在会被解析成基础 `LinkCardPreview`，并在卡片中展示站点名、标题、描述和缩略图。

## 为什么现在不能一次性解决靠“补几个 if”

问题根因不是单个 UI 组件少写了几种分支，而是数据模型从源头就偏单体：

- DTO 层没有抽象“媒体项列表”。
- 领域层没有统一的“消息组预览”表示。
- 服务层只对多音频做了特判。
- 控制器的媒体准备接口默认围绕“当前项的一个主媒体”工作。
- UI 卡片没有图库 / 视频列表 / 富链接卡片的布局抽象。

如果继续沿用现在的特判方式，后面只会出现：

- 多图加一套分支。
- 多视频再加一套分支。
- 富链接再加一套分支。
- 图片大图预览再单独加一套下载逻辑。

这样会把 `TdMessageDto`、`MessagePreview`、`TelegramService`、`MessageViewerCard` 都继续推向更多特殊判断，维护成本会越来越高。

## 一次性重构方向

核心思路：把当前“单主体预览模型”升级为“统一消息组预览模型”，让文本、图片、视频、音频、富链接都变成同一套渲染协议下的不同条目。

### 目标数据模型

建议把当前模型拆成三层：

1. `PipelineMessageGroup`
   - 一个流水线项。
   - 保留 `messageIds`，用于整体分类 / 删除。
   - 包含若干 `PreviewBlock`。

2. `PreviewBlock`
   - 页面上的一个内容块。
   - 类型示例：`text`、`mediaGallery`、`audioPlaylist`、`linkCard`、`unsupported`。

3. `MediaItem`
   - `mediaGallery` 内部的媒体条目。
   - 类型示例：`photo`、`video`。
   - 每一项都有：
     - `messageId`
     - `previewLocalPath`
     - `fullLocalPath`
     - `previewRemoteFileId`
     - `fullRemoteFileId`
     - `duration`
     - `caption`

这样可以自然表达：

- 单图：一个 `mediaGallery`，里面 1 个 `photo`。
- 多图相册：一个 `mediaGallery`，里面 N 个 `photo`。
- 单视频：一个 `mediaGallery`，里面 1 个 `video`。
- 多视频相册：一个 `mediaGallery`，里面 N 个 `video`。
- 多音频：一个 `audioPlaylist`，里面 N 条轨道。
- 富链接：一个 `linkCard`。
- 图文混合：`text` + `mediaGallery` 并存。

### DTO 层重构

`TdMessageDto` 不应只留下“单张图路径 / 单视频路径”，而应明确区分：

- 图片的多尺寸文件集合。
- 视频的缩略图文件与视频文件。
- 文本中的 `link_preview` / `web_page` 信息。
- `media_album_id` 作为分组键。

图片建议至少保留两个级别：

- `previewCandidate`
- `fullCandidate`

不要在 DTO 解析阶段就只取最后一个 size，否则后面无法做“轻量预览图”策略。

### 服务层重构

`TelegramService` 需要从“多音频专用聚合器”改成“通用消息组构建器”：

1. 先按 `media_album_id` 聚合消息。
2. 再把一组消息映射成统一预览块。
3. 对不同媒体类型分别启动预览资源下载：
   - 图片：下载预览尺寸。
   - 视频：下载缩略图。
   - 音频：默认不下载文件，点击轨道时再下载。
4. 分类、删除、撤销始终使用整组 `messageIds`。

这一步做完后，多图 / 多视频就会与多音频一样，成为真正的“一个流水线项”。

### 控制器重构

`PipelineController.prepareCurrentMedia([messageId])` 需要升级成“按媒体项准备资源”的接口，而不是围绕音频 / 视频的两个特殊判断。

建议改成：

- `prepareMediaItem({required int messageId, required PreviewResourceKind kind})`
- `refreshMessageGroup({required int sourceChatId, required int primaryMessageId})`

控制器内部的刷新条件也应由：

- `preview.localVideoPath == null`
- `preview.localAudioPath == null`

改成：

- 当前组内是否仍有 `MediaItem` 处于 `previewPending` 或 `fullPending`

### UI 重构

`MessageViewerCard` 不应继续堆 `if (photo) / if (video) / if (audio)`。建议拆为：

- `MessageViewerCard`
- `preview_blocks/preview_block_renderer.dart`
- `preview_blocks/media_gallery_block.dart`
- `preview_blocks/audio_playlist_block.dart`
- `preview_blocks/link_card_block.dart`
- `preview_blocks/text_block.dart`

展示策略建议：

- 多图片：横向分页或网格缩略图，点击查看原图。
- 多视频：缩略图列表，可逐项播放。
- 多音频：保留当前列表方案，但统一成 playlist block。
- 富链接：展示标题、域名、描述、缩略图；点击外跳浏览器。

### 图片大图预览策略

这部分可以像视频一样做成“两阶段”：

1. 拉取消息页时，只下载较小尺寸的 `photoSize` 作为预览图。
2. 用户点击图片或打开查看器时，再下载更大尺寸或原始尺寸文件。

这要求 DTO 层保留多个 `photoSize` 候选，并在领域层明确：

- `previewFileId`
- `fullFileId`

否则控制器无法知道应该先下载谁。

## 推荐的一次性实施顺序

1. 重做 DTO 和领域模型，让多媒体组成为一等公民。
2. 重写 `TelegramService` 的消息分组与预览构建逻辑。
3. 重构控制器的媒体准备与刷新状态机。
4. 拆分 `MessageViewerCard`，切成 block renderer。
5. 补测试：
   - 多图片相册聚合
   - 多视频相册聚合
   - 图片预览尺寸优先下载
   - 富链接 DTO 解析与卡片渲染
   - 整组分类 / 撤销保持正确 messageIds

## 结论

当前工具能满足：

- 单视频预览
- 单音频预览
- 单图片预览
- 多音频组预览

当前仍未完成的部分主要是：

- 独立 block renderer 文件化拆分
- 原图/原视频的更细粒度查看器体验
- 更多第三方客户端显示差异的对照验证
