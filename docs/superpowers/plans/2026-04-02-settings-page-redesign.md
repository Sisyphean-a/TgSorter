# Settings Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将设置页重构为单页分组的统一草稿表单，移除分散保存按钮，改为页面级一次性保存。

**Architecture:** `SettingsController` 新增 `savedSettings`、`draftSettings` 与脏状态计算，页面所有编辑控件只操作草稿。设置页按“基础流程 / 分类管理 / 连接设置 / 操作与工具”四块重排，底部提供统一保存与放弃更改操作。

**Tech Stack:** Flutter, Dart, GetX, SharedPreferences, flutter_test

---

## Chunk 1: 锁定重构行为

### Task 1: 为控制器草稿模型写失败测试

**Files:**
- Modify: `test/controllers/settings_controller_test.dart`
- Modify: `lib/app/controllers/settings_controller.dart`

- [ ] **Step 1: 写失败测试，覆盖草稿修改会标记 `isDirty`**
- [ ] **Step 2: 写失败测试，覆盖保存后草稿与已保存配置对齐**
- [ ] **Step 3: 写失败测试，覆盖放弃修改恢复已保存配置**
- [ ] **Step 4: 运行 `flutter test test/controllers/settings_controller_test.dart`，确认失败**

### Task 2: 为设置页统一保存 UI 写失败测试

**Files:**
- Create: `test/pages/settings_page_test.dart`
- Modify: `lib/app/pages/settings_page.dart`
- Modify: `lib/app/pages/settings_common_editors.dart`

- [ ] **Step 1: 写失败测试，断言页面存在四个分组标题**
- [ ] **Step 2: 写失败测试，断言页面只存在“保存更改”和“放弃更改”**
- [ ] **Step 3: 写失败测试，断言分类区不再渲染每项“保存”按钮**
- [ ] **Step 4: 运行 `flutter test test/pages/settings_page_test.dart`，确认失败**

## Chunk 2: 控制器重构

### Task 3: 实现统一草稿状态模型

**Files:**
- Modify: `lib/app/controllers/settings_controller.dart`
- Modify: `lib/app/models/app_settings.dart`
- Test: `test/controllers/settings_controller_test.dart`

- [ ] **Step 1: 增加草稿态更新接口，替代逐项立即持久化**
- [ ] **Step 2: 保留验证逻辑，但改为在草稿操作和保存时执行**
- [ ] **Step 3: 实现 `saveDraft()`、`discardDraft()`、`isDirty`**
- [ ] **Step 4: 运行控制器测试，确认通过**

## Chunk 3: 页面重构

### Task 4: 重排设置页分组并接入页面级保存

**Files:**
- Modify: `lib/app/pages/settings_page.dart`
- Modify: `lib/app/pages/settings_common_editors.dart`
- Modify: `lib/app/widgets/shortcut_bindings_editor.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 将现有编辑器改成纯展示/编辑草稿，不直接保存**
- [ ] **Step 2: 在页面中重排四个分组并加入统一底部操作栏**
- [ ] **Step 3: 加入未保存状态提示与放弃更改行为**
- [ ] **Step 4: 重构分类管理为列表式草稿编辑**
- [ ] **Step 5: 运行页面测试，确认通过**

## Chunk 4: 回归

### Task 5: 运行回归验证并同步文档

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: 运行 `flutter test test/controllers/settings_controller_test.dart test/pages/settings_page_test.dart`**
- [ ] **Step 2: 运行 `dart analyze lib test`**
- [ ] **Step 3: 更新文档中的设置页结构与保存模型说明**

Plan complete and saved to `docs/superpowers/plans/2026-04-02-settings-page-redesign.md`. Ready to execute?
