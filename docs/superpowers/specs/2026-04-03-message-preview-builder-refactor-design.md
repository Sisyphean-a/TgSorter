# Message Preview Builder 重构设计

- 日期：2026-04-03
- 设计状态：已进入实现
- 范围：`lib/app/services`、`lib/app/domain`、消息预览相关测试

## 1. 目标

本轮只处理 `TelegramService` 中“相册分组 / 预览组装”相关职责，目标如下：

- 将 `TdMessageDto -> PipelineMessage` 的纯组装逻辑从 `TelegramService` 中拆出；
- 保持 `TelegramGateway` 对外接口不变；
- 保持单条消息、音频组、图片组、视频组的预览行为不变；
- 保持 `latestFirst` / `oldestFirst` 下相册 `messageIds` 顺序不变；
- 为预览组装器增加独立单元测试，降低后续媒体下载链路拆分的成本。

本轮**不处理**媒体下载启动、播放下载、分类事务恢复、分页规则；也**不改**页面与控制器逻辑。

## 2. 现状问题

当前 `TelegramService` 同时承担：

- `_groupPipelineMessages()`：识别相册边界并聚合流水线项；
- `_toPipelineMessage()`：将消息列表包装成 `PipelineMessage`；
- `_buildPreview()`：构建单条 / 音频组 / 相册组预览；
- `_buildMediaGalleryPreview()`：组装图片 / 视频媒体组预览；
- `_firstNonEmptyText()`：为组装逻辑提供 caption 回退策略。

结果是：

- `TelegramService` 同时做“拉取消息 + 预热下载 + 组装预览”，职责继续偏厚；
- 预览组装只能通过服务层间接测试，定位问题成本较高；
- 下一轮若继续拆下载协调器，`TelegramService` 仍然会同时夹带纯转换逻辑和副作用逻辑；
- 相册顺序、caption 选择、媒体主预览选择这些规则没有稳定独立边界。

## 3. 方案选型

### 方案 A：继续保留在 `TelegramService`

优点：

- 改动最小。

缺点：

- 无法继续降低 `TelegramService` 复杂度；
- 第二阶段-B 名义上推进了，但核心预览职责仍未抽离。

### 方案 B：提取纯 `MessagePreviewBuilder`（推荐）

新增一个纯组装器，统一负责：

- 相册分组；
- 单条 / 音频组 / 图片组 / 视频组预览组装；
- `PipelineMessage` 生成；
- caption 与主媒体选择规则。

`TelegramService` 只负责：

- 鉴权；
- 解析来源 chat；
- 调用分页器拿到 `TdMessageDto`；
- 启动媒体预热；
- 调用 builder 组装最终 `PipelineMessage`。

优点：

- 纯逻辑与副作用逻辑明确分离；
- 易于补充高密度单元测试；
- 为下一步拆 `MediaDownloadCoordinator` 留出清晰边界。

缺点：

- 需要新增一个边界类；
- 需要保留服务层回归测试，防止接线错误。

### 方案 C：一次性拆 builder + 下载协调器

优点：

- 结构更完整。

缺点：

- 改动面偏大；
- 测试与回归成本上升；
- 不符合当前“小步、低风险”的节奏。

本轮采用**方案 B**。

## 4. 重构后架构

### 4.1 新增模块

新增：`lib/app/domain/message_preview_builder.dart`

职责：

- 提供 `groupPipelineMessages()`；
- 提供 `toPipelineMessage()`；
- 提供 `buildPreview()`；
- 统一处理相册顺序、caption 回退、首个视频 / 首个媒体选择。

### 4.2 保留在 `TelegramService` 的职责

`TelegramService` 继续负责：

- `fetchMessagePage()` / `fetchNextMessage()` / `refreshMessage()` / `prepareMediaPlayback()` 等对外入口；
- 鉴权检查与 `sourceChatId` 解析；
- 媒体预热与下载启动；
- 分类与撤销编排；
- 调用 `MessageHistoryPaginator` 与 `MessagePreviewBuilder`。

### 4.3 协作边界

新的协作方式：

1. `TelegramService` 完成鉴权与消息拉取；
2. 对拉到的 `TdMessageDto` 逐条执行媒体预热；
3. 调用 `MessagePreviewBuilder.groupPipelineMessages()` 生成流水线项；
4. 单条刷新场景调用 `MessagePreviewBuilder.toPipelineMessage()` 生成预览。

这样可以让 builder 只关心“如何把消息变成预览”，不关心 TDLib 请求与下载副作用。

## 5. 接口设计

### 5.1 `MessagePreviewBuilder`

建议公开：

- `List<PipelineMessage> groupPipelineMessages({required List<TdMessageDto> messages, required int sourceChatId, required MessageFetchDirection direction})`
- `PipelineMessage toPipelineMessage({required List<TdMessageDto> messages, required int sourceChatId})`

内部私有实现：

- `_isGroupedMediaMessage()`
- `_buildPreview()`
- `_buildMediaGalleryPreview()`
- `_firstNonEmptyText()`

### 5.2 所在层级

虽然 builder 没有 IO 副作用，但它依赖 `TdMessageDto`、`PipelineMessage` 和 `MessagePreview` 的组合规则，属于“领域转换逻辑”。因此本轮放在 `lib/app/domain`，与现有 `message_preview_mapper.dart` 相邻，便于后续继续沉淀纯映射逻辑。

## 6. 文件变更计划

### 新增文件

- `lib/app/domain/message_preview_builder.dart`
- `test/domain/message_preview_builder_test.dart`
- `docs/superpowers/specs/2026-04-03-message-preview-builder-refactor-design.md`
- `docs/superpowers/plans/2026-04-03-message-preview-builder-refactor.md`

### 修改文件

- `lib/app/services/telegram_service.dart`
- `test/services/telegram_service_test.dart`（仅保留服务层回归覆盖）
- `docs/ARCHITECTURE.md`

## 7. TDD 实施顺序

### 第一步：先补 builder 测试

覆盖以下行为：

- latest-first 音频相册会聚合成一个 `PipelineMessage`；
- latest-first 图片 / 视频相册会保留升序 `messageIds`；
- oldest-first 不会反转已经按旧到新排列的相册；
- 音频组会生成 `audioTracks`；
- 媒体组会生成 `mediaItems`，并按存在视频时升级为视频组；
- caption 取消息列表中第一条非空文本。

### 第二步：实现 `MessagePreviewBuilder`

- 迁移 `_groupPipelineMessages()` 等纯逻辑；
- 保持原有行为一致；
- 不在 builder 中引入 adapter 或下载相关依赖。

### 第三步：回接 `TelegramService`

- 用 builder 替换服务内部组装逻辑；
- 删除服务中的重复私有方法；
- 保持公开接口和测试语义不变。

### 第四步：定向回归验证

至少运行：

- `flutter test test/domain/message_preview_builder_test.dart`
- `flutter test test/services/telegram_service_test.dart`
- `flutter test test/controllers/pipeline_controller_test.dart`

若时间允许，再补充与第二阶段相关的更多回归测试。

## 8. 风险与回滚点

主要风险：

1. latest-first 相册顺序被误改，导致 `messageIds` 反序；
2. 媒体组主预览选择出错，导致首图 / 首视频丢失；
3. caption 回退规则改变，影响 UI 文案；
4. 服务层接线错误，导致 `refreshMessage()` / `fetchNextMessage()` 返回异常。

控制方式：

- builder 级单测覆盖顺序与预览字段；
- 保留 `telegram_service_test.dart` 回归测试；
- 只拆纯逻辑，不同时改下载策略。
