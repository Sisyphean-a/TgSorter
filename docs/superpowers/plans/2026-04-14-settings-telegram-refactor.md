# Telegram 风格设置彻底重构 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将设置模块彻底重构为接近 Telegram 官方设置的体验，替换掉当前 Material 默认厚表单风格，并同步修正文档边界。

**Architecture:** 保留两层设置导航与页面级草稿保存模型，但重写设置专用设计系统、交互组件和桌面容器。所有选择与输入交互改为列表项驱动的弹层/对话框编辑，详情页不再以常驻下拉框和输入框为主体。

**Tech Stack:** Flutter, Dart, GetX, flutter_test

---

## Chunk 1: 交互约束与主题基线

### Task 1: 先用失败测试锁定新设置交互

**Files:**
- Modify: `test/pages/settings_page_test.dart`
- Modify: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试并确认按预期失败**
- [ ] **Step 3: 断言首页和详情页主视图不再出现 `DropdownButtonFormField`**
- [ ] **Step 4: 断言关键设置项以摘要行呈现，而不是直接显示下拉框和常驻输入框**
- [ ] **Step 5: 断言桌面端设置页使用窄列容器**

### Task 2: 扩展设置专用主题令牌

**Files:**
- Modify: `lib/app/theme/app_tokens.dart`
- Modify: `lib/app/theme/app_theme.dart`
- Test: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: 新增设置页列表、图标、摘要文本、桌面容器等令牌**
- [ ] **Step 2: 收紧全局输入框外观，避免继续主导设置页**
- [ ] **Step 3: 运行主题测试**

## Chunk 2: 设置专用组件系统

### Task 3: 新建 Telegram 风格设置列表组件

**Files:**
- Create: `lib/app/features/settings/presentation/settings_list_tiles.dart`
- Create: `lib/app/features/settings/presentation/settings_surface.dart`
- Create: `lib/app/features/settings/presentation/settings_dialogs.dart`
- Modify: `lib/app/features/settings/presentation/settings_telegram_tiles.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 写组件测试或页面断言需要的失败用例**
- [ ] **Step 2: 实现导航行、值行、开关行、危险动作行、说明行**
- [ ] **Step 3: 实现移动端列表表面与桌面端窄列容器**
- [ ] **Step 4: 实现列表项驱动的选项弹层和输入弹层**
- [ ] **Step 5: 运行相关测试**

### Task 4: 下线旧表单编辑器入口

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 重写旧编辑器为弹层驱动或轻量局部组件**
- [ ] **Step 2: 删除详情页对 `DropdownButtonFormField` 和常驻厚输入框的主依赖**
- [ ] **Step 3: 运行设置页测试**

## Chunk 3: 首页与详情页承载重构

### Task 5: 重构设置首页

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_home_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_app_bar.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 重写首页行样式、分组节奏和摘要表现**
- [ ] **Step 2: 顶栏对齐 Telegram 风格细节**
- [ ] **Step 3: 运行页面测试**

### Task 6: 重构二级页承载

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/settings_detail_page.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 将二级页改成列表块驱动结构**
- [ ] **Step 2: 将选择、输入、开关统一映射到新组件系统**
- [ ] **Step 3: 保留页面草稿保存与放弃逻辑**
- [ ] **Step 4: 运行设置页测试**

## Chunk 4: 分类、标签、连接等复杂区域重写

### Task 7: 重构分类与标签管理

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Modify: `lib/app/features/settings/presentation/tag_group_editor.dart`
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 将分类管理改成列表项 + 局部对话框编辑**
- [ ] **Step 2: 将标签组编辑改成 Telegram 风格列表与轻输入交互**
- [ ] **Step 3: 运行设置页测试**

### Task 8: 重构连接、下载、快捷键和账号页

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 连接与网络改成摘要行 + 输入弹层**
- [ ] **Step 2: 下载与通用设置改成选择行和开关行**
- [ ] **Step 3: 快捷键与账号页统一进新的列表风格**
- [ ] **Step 4: 运行设置页测试**

## Chunk 5: 桌面体验与文档清理

### Task 9: 重构桌面端设置容器

**Files:**
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_surface.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 为桌面端设置内容引入窄列居中布局**
- [ ] **Step 2: 保持移动端与桌面端共享同一套设置组件**
- [ ] **Step 3: 运行设置页测试**

### Task 10: 清理文档与过期入口引用

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/codexpotter/2026-04-13-telegram-settings-two-level-design.md`
- Modify: `docs/codexpotter/2026-04-13-telegram-settings-two-level-todo.md`

- [ ] **Step 1: 将过期的 `settings_page.dart` 引用改为当前真实入口**
- [ ] **Step 2: 删除设置页对旧底部保存条的架构描述**
- [ ] **Step 3: 自查文档边界是否与代码一致**

## Chunk 6: 最终验证

### Task 11: 完整验证

**Files:**
- Test: `test/pages/settings_page_test.dart`
- Test: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: 运行 `flutter test test/pages/settings_page_test.dart test/widgets/app_shell_theme_test.dart`**
- [ ] **Step 2: 运行 `dart analyze`**
- [ ] **Step 3: 记录未完成项或残余风险**
