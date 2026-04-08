# Settings Density And Label Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收紧设置页底部操作区、工作流与分类区的纵向空间，并修复“来源会话”标签裁切。

**Architecture:** 保持现有设置页分组和保存逻辑不变，只调整展示组件的布局密度。优先通过 widget test 固定底栏结构、文案显隐与紧凑布局，再做最小实现修改。

**Tech Stack:** Flutter, Dart, flutter_test

---

## Chunk 1: 设置页密度回归测试

### Task 1: 为设置页紧凑布局写失败测试

**Files:**
- Modify: `test/pages/settings_page_test.dart`
- Reference: `lib/app/shared/presentation/widgets/sticky_action_bar.dart`
- Reference: `lib/app/features/settings/presentation/settings_common_editors.dart`

- [ ] **Step 1: 写失败测试，断言无引用转发副文案消失且底部条仍存在**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/settings_page_test.dart`

- [ ] **Step 3: 实现最小 UI 调整**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/settings_page_test.dart`

### Task 2: 为来源会话标签和分类区紧凑布局补测试

**Files:**
- Modify: `test/pages/settings_page_test.dart`
- Reference: `lib/app/features/settings/presentation/settings_page_parts.dart`

- [ ] **Step 1: 补失败测试，覆盖来源会话标签可见和窄屏不溢出**

- [ ] **Step 2: 运行测试并确认失败或暴露回归**

Run: `flutter test test/pages/settings_page_test.dart`

- [ ] **Step 3: 实现最小布局修复**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/settings_page_test.dart`

## Chunk 2: 回归验证

### Task 3: 运行页面相关回归

**Files:**
- Test: `test/pages/settings_page_test.dart`
- Test: `test/pages/main_shell_page_test.dart`
- Test: `test/pages/logs_screen_test.dart`

- [ ] **Step 1: 运行相关页面测试**

Run: `flutter test test/pages/settings_page_test.dart test/pages/main_shell_page_test.dart test/pages/logs_screen_test.dart`

- [ ] **Step 2: 若失败则修复并重跑**

- [ ] **Step 3: 运行完整 `flutter test` 做最终回归**

Run: `flutter test`
