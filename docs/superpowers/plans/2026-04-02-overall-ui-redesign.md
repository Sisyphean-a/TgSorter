# Overall UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 TgSorter 建立统一品牌化界面系统，并重构工作台与设置页，使其在保持分类效率的前提下显著提升优雅感、流畅度和完成度。

**Architecture:** 先在 `lib/app/app.dart` 之上补齐可复用的设计 token、主题扩展、品牌工具栏、状态组件和工作区容器，再以这些基础组件分别重构桌面端工作台、手机端单手快速流和设置页配置工作区。所有视觉与交互优化都保持现有控制器和业务流程边界，不引入 silent fallback，并通过 widget test 锁定关键布局和状态行为。

**Tech Stack:** Flutter, Dart, Material 3, GetX, flutter_test

---

## Chunk 1: 设计基础设施

### Task 1: 为主题 token 和品牌壳层写失败测试

**Files:**
- Create: `test/widgets/app_shell_theme_test.dart`
- Modify: `lib/app/app.dart`
- Create: `lib/app/theme/app_theme.dart`
- Create: `lib/app/theme/app_tokens.dart`
- Create: `lib/app/widgets/app_shell.dart`
- Create: `lib/app/widgets/brand_app_bar.dart`

- [ ] **Step 1: 写失败测试，断言应用使用统一暗色主题与品牌色 token**
- [ ] **Step 2: 写失败测试，断言工作页使用统一壳层或品牌工具栏，而不是裸 `AppBar`**
- [ ] **Step 3: 运行 `flutter test test/widgets/app_shell_theme_test.dart`，确认失败**

### Task 2: 实现主题 token、品牌工具栏和页面壳层

**Files:**
- Modify: `lib/app/app.dart`
- Create: `lib/app/theme/app_theme.dart`
- Create: `lib/app/theme/app_tokens.dart`
- Create: `lib/app/widgets/app_shell.dart`
- Create: `lib/app/widgets/brand_app_bar.dart`
- Create: `lib/app/widgets/status_badge.dart`
- Test: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: 在 `app_tokens.dart` 中定义颜色、圆角、间距、边框、动画时长常量**
- [ ] **Step 2: 在 `app_theme.dart` 中构建统一 `ThemeData`、`ColorScheme` 和组件主题**
- [ ] **Step 3: 实现 `AppShell` 与 `BrandAppBar`，封装背景、内容宽度、工具栏层级**
- [ ] **Step 4: 实现通用 `StatusBadge`，供工作台和设置页复用**
- [ ] **Step 5: 运行 `flutter test test/widgets/app_shell_theme_test.dart`，确认通过**
- [ ] **Step 6: 提交本任务**

```bash
git add test/widgets/app_shell_theme_test.dart lib/app/app.dart lib/app/theme/app_theme.dart lib/app/theme/app_tokens.dart lib/app/widgets/app_shell.dart lib/app/widgets/brand_app_bar.dart lib/app/widgets/status_badge.dart
git commit -m "feat(ui): add shared application shell and theme tokens"
```

## Chunk 2: 桌面端工作台

### Task 3: 为桌面端双栏工作台写失败测试

**Files:**
- Modify: `test/pages/pipeline_layout_test.dart`
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `lib/app/pages/pipeline_page.dart`
- Modify: `lib/app/pages/pipeline_desktop_view.dart`

- [ ] **Step 1: 写失败测试，断言桌面端存在品牌工具栏、消息区和操作区三段结构**
- [ ] **Step 2: 写失败测试，断言剩余数量与连接状态通过统一状态组件展示**
- [ ] **Step 3: 写失败测试，断言分类操作区独立于消息区渲染**
- [ ] **Step 4: 运行 `flutter test test/pages/pipeline_layout_test.dart test/widgets/message_viewer_card_test.dart`，确认失败**

### Task 4: 实现桌面端双栏工作台结构

**Files:**
- Modify: `lib/app/pages/pipeline_page.dart`
- Modify: `lib/app/pages/pipeline_desktop_view.dart`
- Modify: `lib/app/pages/pipeline_desktop_panels.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Create: `lib/app/widgets/workspace_panel.dart`
- Create: `lib/app/widgets/classification_action_group.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/widgets/message_viewer_card_test.dart`

- [ ] **Step 1: 将页面顶层接入 `AppShell` 与 `BrandAppBar`**
- [ ] **Step 2: 拆出桌面端消息面板与操作面板容器，形成稳定双栏**
- [ ] **Step 3: 重构 `MessageViewerCard` 的标题、媒体、正文、空状态层级**
- [ ] **Step 4: 抽出统一分类按钮组组件，替换散落 `ElevatedButton`**
- [ ] **Step 5: 将日志、错误和快捷键提示降级到次级面板层**
- [ ] **Step 6: 运行 `flutter test test/pages/pipeline_layout_test.dart test/widgets/message_viewer_card_test.dart`，确认通过**
- [ ] **Step 7: 提交本任务**

```bash
git add lib/app/pages/pipeline_page.dart lib/app/pages/pipeline_desktop_view.dart lib/app/pages/pipeline_desktop_panels.dart lib/app/widgets/message_viewer_card.dart lib/app/widgets/workspace_panel.dart lib/app/widgets/classification_action_group.dart test/pages/pipeline_layout_test.dart test/widgets/message_viewer_card_test.dart
git commit -m "feat(ui): redesign desktop pipeline workspace"
```

## Chunk 3: 手机端单手快速流

### Task 5: 为手机端快速流布局写失败测试

**Files:**
- Modify: `test/pages/pipeline_mobile_view_test.dart`
- Modify: `lib/app/pages/pipeline_mobile_view.dart`

- [ ] **Step 1: 写失败测试，断言消息卡片占据主视觉区域**
- [ ] **Step 2: 写失败测试，断言主分类动作固定在底部操作区**
- [ ] **Step 3: 写失败测试，断言次要动作与主分类按钮分层**
- [ ] **Step 4: 运行 `flutter test test/pages/pipeline_mobile_view_test.dart`，确认失败**

### Task 6: 实现手机端单手快速流

**Files:**
- Modify: `lib/app/pages/pipeline_mobile_view.dart`
- Modify: `lib/app/pages/pipeline_page.dart`
- Modify: `lib/app/widgets/message_viewer_card.dart`
- Create: `lib/app/widgets/mobile_action_tray.dart`
- Test: `test/pages/pipeline_mobile_view_test.dart`

- [ ] **Step 1: 将消息区和主操作区改成上下明确分层**
- [ ] **Step 2: 新建 `MobileActionTray`，固定主分类动作与次级按钮布局**
- [ ] **Step 3: 调整消息卡片在移动端的留白、圆角和媒体高度**
- [ ] **Step 4: 运行 `flutter test test/pages/pipeline_mobile_view_test.dart`，确认通过**
- [ ] **Step 5: 提交本任务**

```bash
git add lib/app/pages/pipeline_mobile_view.dart lib/app/pages/pipeline_page.dart lib/app/widgets/message_viewer_card.dart lib/app/widgets/mobile_action_tray.dart test/pages/pipeline_mobile_view_test.dart
git commit -m "feat(ui): redesign mobile pipeline flow"
```

## Chunk 4: 设置页配置工作区

### Task 7: 为设置页视觉重构写失败测试

**Files:**
- Modify: `test/pages/settings_page_test.dart`
- Modify: `test/widgets/app_error_panel_test.dart`
- Modify: `lib/app/pages/settings_page.dart`
- Modify: `lib/app/widgets/settings_section_card.dart`

- [ ] **Step 1: 写失败测试，断言设置页使用统一壳层和固定操作托盘**
- [ ] **Step 2: 写失败测试，断言分组卡片展示统一标题、副标题和已修改状态**
- [ ] **Step 3: 写失败测试，断言保存区在有修改时突出显示**
- [ ] **Step 4: 运行 `flutter test test/pages/settings_page_test.dart test/widgets/app_error_panel_test.dart`，确认失败**

### Task 8: 实现设置页工作区风格

**Files:**
- Modify: `lib/app/pages/settings_page.dart`
- Modify: `lib/app/pages/settings_sections.dart`
- Modify: `lib/app/pages/settings_page_parts.dart`
- Modify: `lib/app/widgets/settings_section_card.dart`
- Modify: `lib/app/widgets/shortcut_bindings_editor.dart`
- Create: `lib/app/widgets/sticky_action_bar.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 将设置页接入 `AppShell`、统一间距和品牌工具栏**
- [ ] **Step 2: 升级 `SettingsSectionCard` 的表面层级、标题区和已修改标记**
- [ ] **Step 3: 实现固定底部操作托盘，强化保存和放弃更改状态**
- [ ] **Step 4: 统一弹窗、提示条和分组间距风格**
- [ ] **Step 5: 运行 `flutter test test/pages/settings_page_test.dart test/widgets/app_error_panel_test.dart`，确认通过**
- [ ] **Step 6: 提交本任务**

```bash
git add lib/app/pages/settings_page.dart lib/app/pages/settings_sections.dart lib/app/pages/settings_page_parts.dart lib/app/widgets/settings_section_card.dart lib/app/widgets/shortcut_bindings_editor.dart lib/app/widgets/sticky_action_bar.dart test/pages/settings_page_test.dart test/widgets/app_error_panel_test.dart
git commit -m "feat(ui): redesign settings workspace"
```

## Chunk 5: 回归与文档

### Task 9: 运行回归并同步说明

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/superpowers/specs/2026-04-02-overall-ui-redesign-design.md`

- [ ] **Step 1: 运行 `flutter test test/widgets/app_shell_theme_test.dart test/pages/pipeline_layout_test.dart test/pages/pipeline_mobile_view_test.dart test/widgets/message_viewer_card_test.dart test/pages/settings_page_test.dart test/widgets/app_error_panel_test.dart`**
- [ ] **Step 2: 运行 `dart analyze lib test`**
- [ ] **Step 3: 更新 `README.md` 与 `docs/ARCHITECTURE.md`，补充新的界面结构与设计系统说明**
- [ ] **Step 4: 提交本任务**

```bash
git add README.md docs/ARCHITECTURE.md docs/superpowers/specs/2026-04-02-overall-ui-redesign-design.md
git commit -m "docs: update ui architecture notes"
```

Plan complete and saved to `docs/superpowers/plans/2026-04-02-overall-ui-redesign.md`. Ready to execute?
