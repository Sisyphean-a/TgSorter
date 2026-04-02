# Message Preview Structure Refactor Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将消息预览链路从单一巨型文件拆分为按预览领域组织的稳定组件结构，在保持现有行为不变的前提下降低复杂度并提升可维护性。

**Architecture:** 保留 `MessageViewerCard` 作为外部入口，只负责卡片壳层、头部和加载遮罩；把预览内容分发、文本/链接、媒体、音频及辅助 UI 分别拆到独立文件。通过先补失败测试再拆分实现的方式，确保视频/音频下载行为、卡片头部和空状态不发生回归。

**Tech Stack:** Flutter, Dart, GetX, flutter_test, video_player, just_audio

---

## Chunk 1: 保护现有行为

### Task 1: 为消息预览拆分补失败测试

**Files:**
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`

- [ ] **Step 1: 写失败测试，断言卡片头部与空状态入口仍然存在**
- [ ] **Step 2: 写失败测试，断言文本/链接/视频/音频预览仍走现有行为**
- [ ] **Step 3: 写失败测试，断言多视频组与音频轨道列表不回归**
- [ ] **Step 4: 运行 `flutter test test/widgets/message_viewer_card_test.dart`，确认失败**

## Chunk 2: 按领域拆分消息预览

### Task 2: 拆出卡片壳层与内容路由

**Files:**
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Create: `lib/app/widgets/message_preview_content.dart`
- Create: `lib/app/widgets/message_preview_helpers.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 在 `message_viewer_card.dart` 中只保留入口卡片、头部、滚动容器和处理中遮罩**
- [ ] **Step 2: 新建 `message_preview_content.dart`，按 `MessagePreviewKind` 分发具体内容**
- [ ] **Step 3: 新建 `message_preview_helpers.dart`，收敛时长、占位态和局部共用组件**
- [ ] **Step 4: 运行 `flutter test test/widgets/message_viewer_card_test.dart`，确认通过**
- [ ] **Step 5: 提交本任务**

```bash
git add lib/app/widgets/message_viewer_card.dart lib/app/widgets/message_preview_content.dart lib/app/widgets/message_preview_helpers.dart test/widgets/message_viewer_card_test.dart
git commit -m "refactor(ui): split message preview shell and routing"
```

### Task 3: 拆出文本与链接预览

**Files:**
- Create: `lib/app/widgets/message_preview_text.dart`
- Create: `lib/app/widgets/message_preview_link.dart`
- Modify: `lib/app/widgets/message_preview_content.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 将富文本与实体链接渲染迁移到 `message_preview_text.dart`**
- [ ] **Step 2: 将链接卡片迁移到 `message_preview_link.dart`**
- [ ] **Step 3: 更新内容分发器，接线到新的文本/链接组件**
- [ ] **Step 4: 运行 `flutter test test/widgets/message_viewer_card_test.dart`，确认通过**
- [ ] **Step 5: 提交本任务**

```bash
git add lib/app/widgets/message_preview_text.dart lib/app/widgets/message_preview_link.dart lib/app/widgets/message_preview_content.dart lib/app/widgets/message_viewer_card.dart test/widgets/message_viewer_card_test.dart
git commit -m "refactor(ui): extract text and link preview renderers"
```

### Task 4: 拆出媒体预览

**Files:**
- Create: `lib/app/widgets/message_preview_media.dart`
- Modify: `lib/app/widgets/message_preview_content.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 将图片、多图、视频、多视频组渲染迁移到 `message_preview_media.dart`**
- [ ] **Step 2: 保留视频下载、缩略图、错误态和播放控制行为不变**
- [ ] **Step 3: 顺手统一媒体占位态和时长信息的局部表现**
- [ ] **Step 4: 运行 `flutter test test/widgets/message_viewer_card_test.dart`，确认通过**
- [ ] **Step 5: 提交本任务**

```bash
git add lib/app/widgets/message_preview_media.dart lib/app/widgets/message_preview_content.dart lib/app/widgets/message_viewer_card.dart test/widgets/message_viewer_card_test.dart
git commit -m "refactor(ui): extract media preview renderer"
```

### Task 5: 拆出音频预览

**Files:**
- Create: `lib/app/widgets/message_preview_audio.dart`
- Modify: `lib/app/widgets/message_preview_content.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 将单音频与多音频轨道列表迁移到 `message_preview_audio.dart`**
- [ ] **Step 2: 保留下载触发、播放切换与轨道展示行为不变**
- [ ] **Step 3: 顺手统一音频占位文案和局部间距**
- [ ] **Step 4: 运行 `flutter test test/widgets/message_viewer_card_test.dart`，确认通过**
- [ ] **Step 5: 提交本任务**

```bash
git add lib/app/widgets/message_preview_audio.dart lib/app/widgets/message_preview_content.dart lib/app/widgets/message_viewer_card.dart test/widgets/message_viewer_card_test.dart
git commit -m "refactor(ui): extract audio preview renderer"
```

## Chunk 3: 收口与回归

### Task 6: 完成回归与文档同步

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/superpowers/specs/2026-04-02-message-preview-structure-refactor-design.md`

- [ ] **Step 1: 运行 `flutter test test/widgets/message_viewer_card_test.dart test/pages/pipeline_layout_test.dart test/pages/pipeline_mobile_view_test.dart`**
- [ ] **Step 2: 运行 `dart analyze lib test`**
- [ ] **Step 3: 更新 `README.md` 与 `docs/ARCHITECTURE.md`，补充新的消息预览文件结构说明**
- [ ] **Step 4: 提交本任务**

```bash
git add README.md docs/ARCHITECTURE.md docs/superpowers/specs/2026-04-02-message-preview-structure-refactor-design.md
git commit -m "docs: update message preview architecture notes"
```

Plan complete and saved to `docs/superpowers/plans/2026-04-02-message-preview-structure-refactor.md`. Ready to execute?
