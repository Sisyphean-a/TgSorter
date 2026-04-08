# Settings And Logs Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将登录后主壳层扩展为工作台、设置、日志三页，并把设置页改造成折叠式大类配置，把日志页改造成按消息链路聚合的独立页面。

**Architecture:** 保持现有 `MainShellPage` 作为统一入口，新增日志 destination 和独立日志屏幕。设置页去掉内嵌最近操作面板，改为四个可独立展开的分组；日志页基于 `ClassifyOperationLog` 聚合出链路视图模型，再由专用组件渲染筛选条和时间线卡片。

**Tech Stack:** Flutter, Dart, GetX, flutter_test

---

## Chunk 1: 顶层导航扩展

### Task 1: 为三页主壳层写失败测试

**Files:**
- Modify: `test/pages/main_shell_page_test.dart`
- Reference: `lib/app/features/shell/presentation/main_shell_page.dart`
- Reference: `lib/app/features/shell/presentation/main_shell_destination.dart`

- [ ] **Step 1: 写失败测试，断言主壳层存在“工作台/设置/日志”三个入口**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart`

- [ ] **Step 3: 扩展 destination 和 `MainShellPage` 的 `IndexedStack` 为三页**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart`

### Task 2: 接入独立日志页占位内容

**Files:**
- Create: `lib/app/features/settings/presentation/logs_screen.dart`
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Test: `test/pages/main_shell_page_test.dart`

- [ ] **Step 1: 为“切换到日志页后显示日志页内容”补失败测试**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart`

- [ ] **Step 3: 新增日志页最小骨架并接入主壳层**

- [ ] **Step 4: 再次运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart`

## Chunk 2: 设置页折叠重组

### Task 3: 为设置页折叠结构写失败测试

**Files:**
- Modify: `test/pages/main_shell_page_test.dart`
- Modify: `test/pages/settings_page_test.dart`
- Reference: `lib/app/features/settings/presentation/settings_screen.dart`

- [ ] **Step 1: 写失败测试，断言设置页包含四个大类分组且不再显示最近操作**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart test/pages/settings_page_test.dart`

- [ ] **Step 3: 新增折叠分组组件或在现有组件内重组设置布局**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart test/pages/settings_page_test.dart`

### Task 4: 保留草稿行为并迁移工具区内容

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Test: `test/controllers/settings_controller_test.dart`

- [ ] **Step 1: 为折叠后的设置页交互补充失败测试或回归断言**

- [ ] **Step 2: 运行相关测试并确认失败或暴露回归**

Run: `flutter test test/controllers/settings_controller_test.dart test/pages/settings_page_test.dart`

- [ ] **Step 3: 把原“操作与工具”区中的日志移除，仅保留会话刷新与快捷键工具**

- [ ] **Step 4: 运行相关测试并确认通过**

Run: `flutter test test/controllers/settings_controller_test.dart test/pages/settings_page_test.dart`

## Chunk 3: 日志链路聚合

### Task 5: 为日志聚合视图模型写失败测试

**Files:**
- Create: `test/shared/presentation/pipeline_log_view_models_test.dart`
- Modify: `lib/app/shared/presentation/formatters/pipeline_log_formatter.dart`
- Reference: `lib/app/models/classify_operation_log.dart`

- [ ] **Step 1: 写失败测试，覆盖同一消息的失败到重试成功链路聚合**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/shared/presentation/pipeline_log_view_models_test.dart`

- [ ] **Step 3: 实现链路聚合与状态推导，避免在 Widget 内直接拼装**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/shared/presentation/pipeline_log_view_models_test.dart`

### Task 6: 为筛选和失败原因展示写失败测试

**Files:**
- Modify: `test/shared/presentation/pipeline_log_view_models_test.dart`
- Reference: `lib/app/shared/presentation/formatters/pipeline_log_formatter.dart`

- [ ] **Step 1: 写失败测试，覆盖失败中、已恢复、已跳过/已撤销三类筛选**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/shared/presentation/pipeline_log_view_models_test.dart`

- [ ] **Step 3: 完成筛选枚举与失败原因提取逻辑**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/shared/presentation/pipeline_log_view_models_test.dart`

## Chunk 4: 日志页渲染

### Task 7: 为日志页 UI 写失败测试

**Files:**
- Create: `test/pages/logs_screen_test.dart`
- Create: `lib/app/features/settings/presentation/logs_screen.dart`
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`

- [ ] **Step 1: 写失败测试，断言日志页显示筛选条、链路卡片和失败原因**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/logs_screen_test.dart`

- [ ] **Step 3: 实现日志页 UI，包括筛选条、摘要卡片和展开时间线**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/logs_screen_test.dart`

### Task 8: 把日志页接入主壳层真实数据

**Files:**
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Modify: `lib/app/features/settings/ports/pipeline_logs_port.dart`
- Test: `test/pages/main_shell_page_test.dart`

- [ ] **Step 1: 为主壳层中的日志页真实渲染补失败测试**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart test/pages/logs_screen_test.dart`

- [ ] **Step 3: 把 `PipelineLogsPort` 数据接入日志页并完成页面切换**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart test/pages/logs_screen_test.dart`

## Chunk 5: 回归验证

### Task 9: 运行针对性回归

**Files:**
- Test: `test/pages/main_shell_page_test.dart`
- Test: `test/pages/settings_page_test.dart`
- Test: `test/pages/logs_screen_test.dart`
- Test: `test/shared/presentation/pipeline_log_view_models_test.dart`

- [ ] **Step 1: 运行导航、设置和日志相关测试**

Run: `flutter test test/pages/main_shell_page_test.dart test/pages/settings_page_test.dart test/pages/logs_screen_test.dart test/shared/presentation/pipeline_log_view_models_test.dart`

- [ ] **Step 2: 若失败则修复并重跑，直到通过**

- [ ] **Step 3: 运行完整 `flutter test` 做最终回归**

Run: `flutter test`
