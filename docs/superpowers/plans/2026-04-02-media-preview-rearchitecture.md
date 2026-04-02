# Media Preview Rearchitecture Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一次性重构消息预览链路，统一支持多图片、多视频、多音频、富链接，以及图片轻量预览下载策略。

**Architecture:** 以“消息组 + 预览块 + 媒体项”为核心替代现有单体 `MessagePreview`。服务层统一按 `media_album_id` 聚合消息，控制器按媒体项管理下载与刷新，UI 通过 block renderer 渲染图库、播放列表和链接卡片。

**Tech Stack:** Flutter, Dart, GetX, TDLib, flutter_test

---

## Chunk 1: 建模与 DTO 扩展

### Task 1: 扩展 TDLib DTO，保留图片多尺寸与链接预览数据

**Files:**
- Modify: `lib/app/services/td_message_dto.dart`
- Test: `test/services/td_wire_message_parser_test.dart`

- [ ] **Step 1: 写失败测试，覆盖 `messagePhoto` 多尺寸解析与链接预览解析**
- [ ] **Step 2: 运行对应测试，确认失败**
- [ ] **Step 3: 增加图片尺寸 DTO、链接预览 DTO，并接入消息内容解析**
- [ ] **Step 4: 运行测试，确认通过**
- [ ] **Step 5: 提交本任务**

### Task 2: 引入统一预览模型

**Files:**
- Modify: `lib/app/domain/message_preview_mapper.dart`
- Modify: `lib/app/models/pipeline_message.dart`
- Test: `test/domain/message_preview_mapper_test.dart`

- [ ] **Step 1: 写失败测试，定义 `PreviewBlock`、`MediaItem`、`LinkCardPreview` 预期结构**
- [ ] **Step 2: 运行测试，确认失败**
- [ ] **Step 3: 用统一消息组模型替换单体媒体字段**
- [ ] **Step 4: 运行测试，确认通过**
- [ ] **Step 5: 提交本任务**

## Chunk 2: 服务层与控制器重构

### Task 3: 重写消息分组逻辑，统一处理媒体相册

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写失败测试，覆盖多图片、多视频、多音频相册聚合**
- [ ] **Step 2: 运行测试，确认失败**
- [ ] **Step 3: 将 `_groupPipelineMessages()` 改为通用消息组构建器**
- [ ] **Step 4: 增加图片预览尺寸优先下载策略**
- [ ] **Step 5: 运行测试，确认通过**
- [ ] **Step 6: 提交本任务**

### Task 4: 重构媒体准备与刷新状态机

**Files:**
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Test: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 写失败测试，覆盖按媒体项下载、组内刷新和整组 messageIds 保持**
- [ ] **Step 2: 运行测试，确认失败**
- [ ] **Step 3: 将 `prepareCurrentMedia()` 改为按媒体项准备资源**
- [ ] **Step 4: 把刷新条件从单字段判断改为组内媒体状态判断**
- [ ] **Step 5: 运行测试，确认通过**
- [ ] **Step 6: 提交本任务**

## Chunk 3: UI 重构

### Task 5: 拆分消息预览卡片为块渲染架构

**Files:**
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Create: `lib/app/widgets/preview_blocks/preview_block_renderer.dart`
- Create: `lib/app/widgets/preview_blocks/text_block.dart`
- Create: `lib/app/widgets/preview_blocks/media_gallery_block.dart`
- Create: `lib/app/widgets/preview_blocks/audio_playlist_block.dart`
- Create: `lib/app/widgets/preview_blocks/link_card_block.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 写失败测试，覆盖多图、多视频、富链接卡片渲染**
- [ ] **Step 2: 运行测试，确认失败**
- [ ] **Step 3: 将 `MessageViewerCard` 改为 block renderer 容器**
- [ ] **Step 4: 实现图库、播放列表、富链接卡片组件**
- [ ] **Step 5: 运行测试，确认通过**
- [ ] **Step 6: 提交本任务**

## Chunk 4: 回归验证与文档

### Task 6: 补全回归测试并更新文档

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MEDIA_PREVIEW_ANALYSIS.md`
- Test: `test/services/telegram_service_test.dart`
- Test: `test/controllers/pipeline_controller_test.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 运行媒体预览相关测试集**
- [ ] **Step 2: 修复失败用例并确认通过**
- [ ] **Step 3: 更新 README 与架构文档，记录新模型与支持矩阵**
- [ ] **Step 4: 提交本任务**
