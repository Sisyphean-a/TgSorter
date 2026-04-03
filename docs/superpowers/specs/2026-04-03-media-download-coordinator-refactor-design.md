# Media Download Coordinator 重构设计

- 日期：2026-04-03
- 设计状态：已与用户确认总体方案，待审阅 spec
- 范围：`lib/app/services`、媒体下载相关测试

## 1. 目标

本轮只处理 `TelegramService` 中“媒体下载预热 / 播放下载”相关职责，目标如下：

- 将媒体下载策略从 `TelegramService` 中拆出，收口到独立协调器；
- 保持 `TelegramGateway` 对外接口不变；
- 保持图片预热、视频缩略图预热、音频播放下载、视频播放下载的现有行为不变；
- 保持 `fetchMessagePage()`、`fetchNextMessage()`、`prepareMediaPreview()`、`prepareMediaPlayback()` 的对外语义不变；
- 为下载协调器增加独立单元测试，降低后续继续拆分 service 副作用链路的成本。

本轮**不处理**分页规则、预览构建、分类事务恢复；也**不改**页面、控制器和仓储逻辑。

## 2. 现状问题

当前 `TelegramService` 仍然直接承担下载相关职责：

- `_ensureMediaDownloadsStarted()`：处理图片 / 视频缩略图 / 链接卡片图预热；
- `_ensureFileDownloadStarted()`：执行底层 `downloadFile` 请求；
- `prepareMediaPreview()`：加载消息后触发预热；
- `prepareMediaPlayback()`：加载消息后根据媒体类型决定是否下载音频 / 视频文件；
- `fetchMessagePage()`、`fetchNextMessage()`：在消息加载后逐条触发预热下载。

结果是：

- `TelegramService` 既做业务编排，又做下载策略分支；
- 下载优先级、何时预热、何时下载完整媒体文件这些规则仍分散在服务内部；
- `prepareMediaPreview()` / `prepareMediaPlayback()` 的行为只能通过整个服务层间接验证；
- 下一步若继续拆 service 的副作用边界，会被下载逻辑继续阻塞上下文。

## 3. 方案选型

### 方案 A：只提取底层 `downloadFile` 助手

优点：

- 改动最小。

缺点：

- 下载策略分支仍然保留在 `TelegramService`；
- `prepareMediaPreview()` / `prepareMediaPlayback()` 复杂度不会明显下降；
- 收益有限。

### 方案 B：提取完整 `MediaDownloadCoordinator`（推荐）

新增一个独立协调器，统一负责：

- 预览预热下载；
- 播放前完整媒体下载；
- 底层 `downloadFile` 调用与“已存在本地文件则跳过”规则。

`TelegramService` 只负责：

- 鉴权；
- 解析来源 chat；
- 加载消息 DTO；
- 调用 coordinator 触发下载；
- 在需要时刷新消息并继续构建预览。

优点：

- `TelegramService` 继续瘦身；
- 下载策略边界清晰；
- 单测可以直接命中“下载策略是否正确”；
- 与上一轮 `MessagePreviewBuilder` / `MessageHistoryPaginator` 的拆分方向一致。

缺点：

- 需要新增一个服务级边界类；
- 仍需保留 `TelegramService` 回归测试防止接线错误。

### 方案 C：一次性抽出“媒体用例服务”

优点：

- 结构更完整。

缺点：

- 会把“加载消息 + 下载 + 刷新消息”的编排一起挪走；
- 改动面偏大；
- 不符合当前“小步重构”的节奏。

本轮采用**方案 B**。

## 4. 重构后架构

### 4.1 新增模块

新增：`lib/app/services/media_download_coordinator.dart`

职责：

- 提供 `warmUpPreview()`；
- 提供 `preparePlayback()`；
- 封装底层 `downloadFile` 调用；
- 集中管理下载优先级与跳过规则。

### 4.2 保留在 `TelegramService` 的职责

`TelegramService` 继续负责：

- `fetchMessagePage()` / `fetchNextMessage()` / `prepareMediaPreview()` / `prepareMediaPlayback()` 对外入口；
- 鉴权检查与 `sourceChatId` 解析；
- 消息加载与刷新；
- 调用 `MessageHistoryPaginator`、`MessagePreviewBuilder` 与 `MediaDownloadCoordinator`；
- 分类与撤销编排。

### 4.3 协作边界

新的协作方式：

1. `TelegramService` 完成鉴权与消息拉取；
2. 对拉取到的 `TdMessageDto.content` 调用 `MediaDownloadCoordinator.warmUpPreview()`；
3. `prepareMediaPreview()` 仅负责加载消息并委托 coordinator；
4. `prepareMediaPlayback()` 负责加载消息、调用 `preparePlayback()`，然后在需要时刷新消息。

这样可以让 coordinator 只关心“该下载什么”和“是否应该跳过”，不关心授权、拉消息和预览模型组装。

## 5. 接口设计

### 5.1 构造依赖

`MediaDownloadCoordinator` 依赖：

- `TdlibAdapter adapter`

说明：

- 协调器直接调用 adapter 发起 `downloadFile` 请求，避免 `TelegramService` 再中转一层；
- 下载优先级继续由协调器内部常量维护，保持规则集中；
- 不新增 repository / gateway 抽象，保持本轮最小复杂度。

### 5.2 对外方法

建议暴露：

- `Future<void> warmUpPreview(TdMessageContentDto content)`
- `Future<bool> preparePlayback(TdMessageContentDto content)`

说明：

- `warmUpPreview()` 负责图片预览图、视频缩略图、链接卡片图预热；
- `preparePlayback()` 负责音频文件和视频文件下载；
- `preparePlayback()` 返回 `bool`，表示是否触发了“可能改变消息本地文件状态”的下载，供 `TelegramService` 决定是否刷新消息。

### 5.3 内部规则

保留当前语义：

- 图片消息：
  - 预热阶段下载 `remoteImageFileId`；
  - 播放阶段无额外动作。
- 视频消息：
  - 预热阶段只下载 `remoteVideoThumbnailFileId`；
  - 播放阶段下载 `remoteVideoFileId`。
- 音频消息：
  - 预热阶段不下载；
  - 播放阶段下载 `remoteAudioFileId`。
- 文本链接卡片：
  - 若有 `linkPreview.remoteImageFileId`，预热阶段下载卡片图。
- 已有 `localPath` 时：
  - 跳过下载请求。
- `fileId == null` 时：
  - 跳过下载请求。

## 6. 文件变更计划

### 新增文件

- `lib/app/services/media_download_coordinator.dart`
- `test/services/media_download_coordinator_test.dart`
- `docs/superpowers/specs/2026-04-03-media-download-coordinator-refactor-design.md`

### 修改文件

- `lib/app/services/telegram_service.dart`
- `test/services/telegram_service_test.dart`
- `docs/ARCHITECTURE.md`

## 7. TDD 实施顺序

### 第一步：先补协调器测试

新增 `test/services/media_download_coordinator_test.dart`，覆盖：

- 图片预热会下载预览图；
- 视频预热只下载缩略图；
- 音频预热不下载；
- 链接卡片图会预热；
- 音频播放会下载音频文件；
- 视频播放会下载视频文件；
- 已有本地路径 / 缺少 fileId 时不会重复下载。

### 第二步：实现 `MediaDownloadCoordinator`

- 迁移 `_ensureMediaDownloadsStarted()` 与 `_ensureFileDownloadStarted()` 规则；
- 把 `prepareMediaPlayback()` 中的下载分支收口到协调器；
- 保持外部行为不变。

### 第三步：回接 `TelegramService`

- 在 `fetchMessagePage()` / `fetchNextMessage()` 中改为委托 `warmUpPreview()`；
- 在 `prepareMediaPreview()` 中改为委托 `warmUpPreview()`；
- 在 `prepareMediaPlayback()` 中改为委托 `preparePlayback()`，并根据返回值决定是否刷新消息；
- 删除服务中重复的下载私有方法。

### 第四步：定向回归验证

至少运行：

- `flutter test test/services/media_download_coordinator_test.dart`
- `flutter test test/services/telegram_service_test.dart`
- `flutter test test/controllers/pipeline_controller_test.dart`

若时间允许，再补充与媒体预览相关的回归测试。

## 8. 风险与回滚点

主要风险：

1. 视频预热误下了完整视频文件，导致额外 IO；
2. `prepareMediaPlayback()` 刷新时机改变，导致 UI 不更新；
3. 链接卡片图预热遗漏；
4. 本地路径判定错误，导致重复下载。

控制方式：

- 协调器级单测覆盖每种媒体类型和跳过逻辑；
- 保留 `telegram_service_test.dart` 的现有下载回归测试；
- 本轮只拆下载策略，不同时改 DTO 和预览模型。
