# Main Shell Sidebar Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在登录后引入统一主壳层和覆盖式左侧导航抽屉，用它切换工作台与设置，并为后续新增页面预留扩展结构。

**Architecture:** 保持登录页独立，把登录后入口统一收敛到 `/app`。新增主壳层页面承载抽屉和 `IndexedStack` 内容区，把工作台与设置从完整路由页拆成可复用内容组件，从而保留各自状态并集中管理导航。

**Tech Stack:** Flutter, Dart, GetX, flutter_test

---

## Chunk 1: 路由与主壳层骨架

### Task 1: 为主壳层增加失败测试

**Files:**
- Create: `test/pages/main_shell_page_test.dart`
- Reference: `lib/app/core/routing/app_routes.dart`
- Reference: `lib/app/features/pipeline/presentation/pipeline_page.dart`
- Reference: `lib/app/features/settings/presentation/settings_page.dart`

- [ ] **Step 1: 写失败测试，描述主壳层默认显示工作台且能打开抽屉**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart`

- [ ] **Step 3: 新增主壳层页面、destination 定义和最小路由骨架**

- [ ] **Step 4: 再次运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart`

### Task 2: 调整登录后的路由目标

**Files:**
- Modify: `lib/app/core/routing/app_routes.dart`
- Modify: `lib/app/core/routing/getx_auth_navigation_adapter.dart`
- Test: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 为认证成功后进入 `/app` 写失败测试或更新现有测试断言**

- [ ] **Step 2: 运行对应测试并确认失败**

Run: `flutter test test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 3: 实现新路由与导航跳转**

- [ ] **Step 4: 重新运行对应测试并确认通过**

Run: `flutter test test/integration/auth_pipeline_flow_test.dart`

## Chunk 2: 页面内容抽离与壳层集成

### Task 3: 抽离工作台内容组件

**Files:**
- Modify: `lib/app/features/pipeline/presentation/pipeline_page.dart`
- Create: `lib/app/features/pipeline/presentation/pipeline_screen.dart`
- Test: `test/pages/pipeline_layout_test.dart`

- [ ] **Step 1: 为“工作台可作为壳层内容渲染且不依赖设置按钮跳转”写失败测试**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/pipeline_layout_test.dart`

- [ ] **Step 3: 把工作台内容抽离成可嵌入主壳层的组件**

- [ ] **Step 4: 运行测试并确认通过**

Run: `flutter test test/pages/pipeline_layout_test.dart`

### Task 4: 抽离设置内容组件

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Create: `lib/app/features/settings/presentation/settings_screen.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 为“设置可在壳层中独立渲染”写失败测试**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/settings_page_test.dart`

- [ ] **Step 3: 抽离设置内容组件，同时保留底部保存条与草稿行为**

- [ ] **Step 4: 运行测试并确认通过**

Run: `flutter test test/pages/settings_page_test.dart`

## Chunk 3: 主壳层导航行为完善

### Task 5: 完成抽屉导航切换与状态保持

**Files:**
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Modify: `lib/app/features/shell/presentation/main_shell_destination.dart`
- Test: `test/pages/main_shell_page_test.dart`

- [ ] **Step 1: 为“点击导航项后切换页面、关闭抽屉并高亮当前项”补失败测试**

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart`

- [ ] **Step 3: 用 `IndexedStack` 完成页面切换和高亮逻辑**

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart`

## Chunk 4: 回归验证

### Task 6: 运行页面与流程回归测试

**Files:**
- Test: `test/pages/main_shell_page_test.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/pages/settings_page_test.dart`
- Test: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 运行主壳层与相关页面测试**

Run: `flutter test test/pages/main_shell_page_test.dart test/pages/pipeline_layout_test.dart test/pages/settings_page_test.dart test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 2: 若失败则修复并重跑，直到全部通过**

- [ ] **Step 3: 运行 `flutter test` 做最终回归抽查**

Run: `flutter test`
