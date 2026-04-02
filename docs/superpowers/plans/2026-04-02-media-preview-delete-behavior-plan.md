# Media Preview And Delete Behavior Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构消息预览链路，统一支持多媒体组与富链接，并修复安卓“跳过”误判和删除语义不贴近官方的问题。

**Architecture:** 使用“消息组 + 预览块 + 媒体项”替代现有单体 `MessagePreview` 结构。服务层统一聚合相册消息并尝试官方优先删除路径，UI 层拆分为 block renderer，安卓误判通过文案与语义标签替换解决。

**Tech Stack:** Flutter, Dart, GetX, TDLib, flutter_test

---

## Chunk 1: 先锁定行为与风险

### Task 1: 为安卓跳过误判与删除回退写失败测试

**Files:**
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`
- Modify: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写失败测试，断言 UI 中不再出现“跳过当前”文案**
- [ ] **Step 2: 写失败测试，断言删除优先路径失败后会回退旧逻辑**
- [ ] **Step 3: 运行对应测试，确认失败**
- [ ] **Step 4: 提交本任务**

## Chunk 2: DTO 与统一预览模型

### Task 2: 扩展消息 DTO，保留图片尺寸候选与富链接信息

**Files:**
- Modify: `lib/app/services/td_message_dto.dart`
- Test: `test/services/td_wire_message_parser_test.dart`

- [ ] **Step 1: 写失败测试，覆盖 `messagePhoto` 多尺寸候选解析**
- [ ] **Step 2: 写失败测试，覆盖富链接预览字段解析**
- [ ] **Step 3: 运行测试，确认失败**
- [ ] **Step 4: 实现 DTO 扩展**
- [ ] **Step 5: 运行测试，确认通过**
- [ ] **Step 6: 提交本任务**

### Task 3: 引入统一预览块模型

**Files:**
- Modify: `lib/app/domain/message_preview_mapper.dart`
- Modify: `lib/app/models/pipeline_message.dart`
- Test: `test/domain/message_preview_mapper_test.dart`

- [ ] **Step 1: 写失败测试，定义 `PreviewBlock` / `MediaItem` / `LinkCardPreview` 行为**
- [ ] **Step 2: 运行测试，确认失败**
- [ ] **Step 3: 实现统一预览模型并移除单媒体中心结构**
- [ ] **Step 4: 运行测试，确认通过**
- [ ] **Step 5: 提交本任务**

## Chunk 3: 服务层重写

### Task 4: 统一聚合相册消息并实现图片预览优先下载

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写失败测试，覆盖多图片、多视频、多音频相册聚合**
- [ ] **Step 2: 写失败测试，覆盖图片先下载预览尺寸**
- [ ] **Step 3: 运行测试，确认失败**
- [ ] **Step 4: 重写分组与下载策略**
- [ ] **Step 5: 运行测试，确认通过**
- [ ] **Step 6: 提交本任务**

### Task 5: 实现官方优先删除路径与旧逻辑回退

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写失败测试，覆盖新删除路径成功场景**
- [ ] **Step 2: 写失败测试，覆盖新删除路径失败后回退旧逻辑场景**
- [ ] **Step 3: 运行测试，确认失败**
- [ ] **Step 4: 实现删除优先链路与回退**
- [ ] **Step 5: 运行测试，确认通过**
- [ ] **Step 6: 提交本任务**

## Chunk 4: 控制器与 UI

### Task 6: 按媒体项重构控制器刷新逻辑

**Files:**
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Test: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 写失败测试，覆盖媒体项级别准备与组内刷新**
- [ ] **Step 2: 运行测试，确认失败**
- [ ] **Step 3: 实现按媒体项准备资源的控制器逻辑**
- [ ] **Step 4: 运行测试，确认通过**
- [ ] **Step 5: 提交本任务**

### Task 7: 拆分消息预览 UI，并替换安卓误判文案

**Files:**
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Create: `lib/app/widgets/preview_blocks/preview_block_renderer.dart`
- Create: `lib/app/widgets/preview_blocks/text_block.dart`
- Create: `lib/app/widgets/preview_blocks/media_gallery_block.dart`
- Create: `lib/app/widgets/preview_blocks/audio_playlist_block.dart`
- Create: `lib/app/widgets/preview_blocks/link_card_block.dart`
- Modify: `lib/app/pages/pipeline_mobile_view.dart`
- Modify: `lib/app/pages/pipeline_desktop_panels.dart`
- Modify: `lib/app/widgets/shortcut_bindings_editor.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 写失败测试，覆盖多图、多视频、富链接卡片渲染**
- [ ] **Step 2: 写失败测试，覆盖“略过此条”文案替换**
- [ ] **Step 3: 运行测试，确认失败**
- [ ] **Step 4: 拆分 `MessageViewerCard` 并实现 block renderer**
- [ ] **Step 5: 替换所有用户可见“跳过当前”文案**
- [ ] **Step 6: 运行测试，确认通过**
- [ ] **Step 7: 提交本任务**

## Chunk 5: 回归与文档

### Task 8: 跑回归并更新项目文档

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/MEDIA_PREVIEW_ANALYSIS.md`

- [ ] **Step 1: 运行媒体预览、控制器、服务层测试集**
- [ ] **Step 2: 修复失败用例并确认通过**
- [ ] **Step 3: 更新文档中的支持矩阵与删除策略说明**
- [ ] **Step 4: 提交本任务**
