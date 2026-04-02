# Pipeline Stats And Prefetch Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为流水线页增加剩余总数统计、移除失败重试 UI，并加入可配置的后续预览预加载。

**Architecture:** 在 `SettingsController` / `AppSettings` 中引入 `previewPrefetchCount`，在 `TelegramService` 中新增剩余计数与预览预加载接口，在 `PipelineController` 中统一维护 `remainingCount` 和预加载窗口。UI 只负责展示统计和收掉低价值重试控件。

**Tech Stack:** Flutter, Dart, GetX, TDLib, flutter_test

---

## Chunk 1: 锁定行为

### Task 1: 为剩余总数与预加载写失败测试

**Files:**
- Modify: `test/controllers/pipeline_controller_test.dart`
- Modify: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 写失败测试，覆盖初次抓取后的剩余总数初始化**
- [ ] **Step 2: 写失败测试，覆盖分类成功后剩余总数递减**
- [ ] **Step 3: 写失败测试，覆盖后续 N 条预加载只触发预览资源**
- [ ] **Step 4: 运行对应测试，确认失败**

### Task 2: 为页面调整写失败测试

**Files:**
- Modify: `test/pages/pipeline_mobile_view_test.dart`
- Modify: `test/pages/pipeline_layout_test.dart`
- Modify: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 写失败测试，断言移动端显示剩余总数**
- [ ] **Step 2: 写失败测试，断言失败重试队列 UI 已移除**
- [ ] **Step 3: 写失败测试，断言设置页存在“预加载后续预览”选项**
- [ ] **Step 4: 运行对应测试，确认失败**

## Chunk 2: 设置与服务层

### Task 3: 扩展设置模型

**Files:**
- Modify: `lib/app/models/app_settings.dart`
- Modify: `lib/app/services/settings_repository.dart`
- Modify: `lib/app/controllers/settings_controller.dart`
- Modify: `lib/app/pages/settings_common_editors.dart`
- Modify: `lib/app/pages/settings_sections.dart`

- [ ] **Step 1: 新增 `previewPrefetchCount` 到设置模型与仓储**
- [ ] **Step 2: 在设置控制器中接入草稿编辑与保存**
- [ ] **Step 3: 在设置页基础流程中加入预加载选项**
- [ ] **Step 4: 运行设置相关测试，确认通过**

### Task 4: 扩展服务层接口

**Files:**
- Modify: `lib/app/services/telegram_gateway.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 增加 `countRemainingMessages` 接口**
- [ ] **Step 2: 增加 `prepareMediaPreview` 接口**
- [ ] **Step 3: 实现视频缩略图和图片预览的轻量预加载**
- [ ] **Step 4: 运行服务层测试，确认通过**

## Chunk 3: 控制器与 UI

### Task 5: 在流水线控制器中接入统计和预加载

**Files:**
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Test: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 新增 `remainingCount` 与 `remainingCountLoading` 状态**
- [ ] **Step 2: 在抓取、分类、撤销和设置切换时更新统计**
- [ ] **Step 3: 在当前消息变化和缓存追加时触发后续预加载**
- [ ] **Step 4: 运行控制器测试，确认通过**

### Task 6: 调整流水线页展示

**Files:**
- Modify: `lib/app/pages/pipeline_mobile_view.dart`
- Modify: `lib/app/pages/pipeline_desktop_panels.dart`
- Modify: `lib/app/pages/pipeline_desktop_view.dart`
- Test: `test/pages/pipeline_mobile_view_test.dart`
- Test: `test/pages/pipeline_layout_test.dart`

- [ ] **Step 1: 增加剩余总数轻量显示**
- [ ] **Step 2: 移除失败重试队列和重试下一条 UI**
- [ ] **Step 3: 运行页面测试，确认通过**

## Chunk 4: 回归与文档

### Task 7: 更新文档并跑回归

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: 更新 README 和架构文档中的流水线状态说明**
- [ ] **Step 2: 运行 `dart analyze lib test`**
- [ ] **Step 3: 运行与流水线、设置相关的回归测试**

Plan complete and saved to `docs/superpowers/plans/2026-04-02-pipeline-stats-prefetch.md`. Ready to execute?
