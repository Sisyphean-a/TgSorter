# 全局双主题与 Telegram 风格重构实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持现有页面结构和业务流程基本不变的前提下，为应用建立浅色 / 深色 / 跟随系统三种主题模式，默认浅色，并把导航层、设置页、转发工作台、标签工作台、日志页统一收口为 Telegram 风格的轻量视觉体系。

**Architecture:** 先把主题模式接入 `AppSettings` 和应用根节点，再重建语义化双主题 token 与 `ThemeData`，随后改造共享壳层与共用组件，最后逐页把设置、工作台、日志接入新主题语义。页面结构保持稳定，主要调整颜色、边界、行高、间距、控件样式和列表化分组。

**Tech Stack:** Flutter, Dart, GetX, SharedPreferences, flutter_test

---

## Chunk 1: 主题模式接入设置链路

### Task 1: 为主题模式模型与持久化写失败测试

**Files:**
- Create: `lib/app/models/app_theme_mode.dart`
- Modify: `lib/app/models/app_settings.dart`
- Modify: `lib/app/services/settings_repository.dart`
- Test: `test/models/app_settings_shortcut_test.dart`
- Test: `test/services/settings_repository_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 默认主题模式为 `light`
- `copyWith` 可以更新主题模式
- 等值性包含主题模式
- 仓库能正确保存和读取主题模式

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/models/app_settings_shortcut_test.dart test/services/settings_repository_test.dart --reporter compact`

- [ ] **Step 3: 实现最小模型与持久化改动**

新增：

- `AppThemeMode.light`
- `AppThemeMode.dark`
- `AppThemeMode.system`

并把主题模式纳入 `AppSettings` 与 `SettingsRepository`。

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/models/app_settings_shortcut_test.dart test/services/settings_repository_test.dart --reporter compact`

### Task 2: 让设置协调器支持主题模式草稿

**Files:**
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
- Test: `test/features/settings/application/settings_coordinator_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 从浅色切换到深色的草稿更新
- 放弃草稿后恢复已保存主题模式

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/features/settings/application/settings_coordinator_test.dart --reporter compact`

- [ ] **Step 3: 实现主题模式草稿更新接口**

建议接口：

```dart
void updateThemeModeDraft(AppThemeMode mode)
```

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/features/settings/application/settings_coordinator_test.dart --reporter compact`

---

## Chunk 2: 重建全局主题基础层

### Task 3: 为双主题 token 和主题构建器写失败测试

**Files:**
- Modify: `lib/app/theme/app_tokens.dart`
- Modify: `lib/app/theme/app_theme.dart`
- Create: `lib/app/theme/app_theme_scope.dart`
- Test: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 浅色主题具备浅底、白面、蓝色强调的基本语义
- 深色主题具备中性深灰而非旧版偏绿语义
- 按钮、输入框、分割线等组件从主题读取颜色

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/widgets/app_shell_theme_test.dart --reporter compact`

- [ ] **Step 3: 实现双主题 token 与主题构建器**

主题语义至少包括：

- 页面背景
- 导航背景
- 顶栏背景
- 内容面
- 次级内容面
- 分割线
- 文本层级
- 主色 / 成功 / 警告 / 危险
- 选中态背景和前景

同时提供：

- `AppTheme.light()`
- `AppTheme.dark()`
- 主题模式解析辅助

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/widgets/app_shell_theme_test.dart --reporter compact`

### Task 4: 把主题模式应用到应用根节点

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/core/di/app_bindings.dart`（如根节点接入需要）
- Test: `test/app/cross_feature_ports_di_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 应用根节点能读取已保存主题模式
- `GetMaterialApp` 能同时接入 `theme`、`darkTheme`、`themeMode`

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/app/cross_feature_ports_di_test.dart --reporter compact`

- [ ] **Step 3: 实现根节点接线**

要求：

- 默认浅色
- 深色模式正常切换
- 跟随系统模式正常透传

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/app/cross_feature_ports_di_test.dart --reporter compact`

---

## Chunk 3: 导航层与共享组件收口

### Task 5: 重做主壳层与导航视觉

**Files:**
- Modify: `lib/app/shared/presentation/widgets/app_shell.dart`
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Modify: `lib/app/shared/presentation/widgets/status_badge.dart`
- Test: `test/pages/main_shell_page_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 壳层不再使用旧版重渐变背景
- 抽屉导航项在浅色主题下更像连续列表行
- 选中导航态在浅色和深色下都清晰可见

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/main_shell_page_test.dart --reporter compact`

- [ ] **Step 3: 实现最小导航层重构**

包括：

- 页背景
- 顶栏背景与文字层级
- 抽屉项间距、选中态、分割线
- 状态徽标主题化

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/main_shell_page_test.dart --reporter compact`

### Task 6: 重做工作台与日志共用表面组件

**Files:**
- Modify: `lib/app/shared/presentation/widgets/workspace_panel.dart`
- Modify: `lib/app/shared/presentation/widgets/message_viewer_card.dart`
- Modify: `lib/app/features/workbench/presentation/message_workbench_view.dart`
- Test: `test/widgets/message_viewer_card_test.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/pages/tagging_page_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 共用面板在浅色主题下不再表现为旧版厚重卡片
- 预览容器、操作容器边界更轻
- 转发与标签工作台在新样式下无溢出

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/widgets/message_viewer_card_test.dart test/pages/pipeline_layout_test.dart test/pages/tagging_page_test.dart --reporter compact`

- [ ] **Step 3: 实现共享表面组件重构**

包括：

- 面板背景
- 边框与分割线
- 标题与辅助文本层级
- 移动端与桌面端容器间距

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/widgets/message_viewer_card_test.dart test/pages/pipeline_layout_test.dart test/pages/tagging_page_test.dart --reporter compact`

---

## Chunk 4: 设置页视觉重做

### Task 7: 为 Telegram 风格设置页写失败测试

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Modify: `lib/app/features/settings/presentation/settings_list_section.dart`
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/tag_group_editor.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 浅色主题下设置页呈现为 section + 列表行，而不是大卡片堆叠
- `转发区设置 / 标签区设置 / 通用设置` 三大区稳定存在
- section 标题、行分割线、编辑器样式符合新主题语义
- `主题模式` 编辑项位于通用设置中

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/settings_page_test.dart --reporter compact`

- [ ] **Step 3: 实现设置页视觉重做**

要求：

- 页面底色和区块底色层次清晰
- section 标题采用 Telegram 风格蓝色小标题
- 输入框、选择器、开关融入列表行
- 默认标签组编辑器也改为轻量列表式区域
- 继续保留底部保存 / 放弃草稿逻辑

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/settings_page_test.dart --reporter compact`

---

## Chunk 5: 工作台页面视觉收口

### Task 8: 重做转发工作台页面外观

**Files:**
- Modify: `lib/app/features/pipeline/presentation/pipeline_page.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/pages/pipeline_mobile_view_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 转发工作台顶栏在浅色模式下不再继承旧深色样式
- 分类动作区与预览区边界符合新主题
- 桌面端和移动端布局稳定

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/pipeline_layout_test.dart test/pages/pipeline_mobile_view_test.dart --reporter compact`

- [ ] **Step 3: 实现转发工作台视觉收口**

包括：

- 顶栏样式
- 操作区和状态区边界
- 次级按钮和辅助信息层级

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/pipeline_layout_test.dart test/pages/pipeline_mobile_view_test.dart --reporter compact`

### Task 9: 重做标签工作台页面外观

**Files:**
- Modify: `lib/app/features/tagging/presentation/tagging_page.dart`
- Modify: `lib/app/features/tagging/presentation/tag_action_group.dart`
- Test: `test/pages/tagging_page_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 标签工作台与转发工作台共享同一视觉语言
- 标签按钮样式接入新主题而非旧强调色
- 页面在浅色和深色模式下都保持稳定渲染

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/tagging_page_test.dart --reporter compact`

- [ ] **Step 3: 实现标签工作台视觉收口**

包括：

- 顶栏
- 标签按钮组
- 操作区与消息预览的边界一致性

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/tagging_page_test.dart --reporter compact`

---

## Chunk 6: 日志页视觉收口

### Task 10: 重做日志页外观

**Files:**
- Modify: `lib/app/features/settings/presentation/logs_screen.dart`
- Test: `test/pages/logs_screen_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- 筛选条和日志项在浅色模式下具备更轻的列表感
- 空状态和状态徽标接入新主题
- 页面在新主题下保持可读和可筛选

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/pages/logs_screen_test.dart --reporter compact`

- [ ] **Step 3: 实现日志页视觉收口**

包括：

- 筛选条样式
- 日志行 / 链路块样式
- 空状态与状态徽标的主题化

- [ ] **Step 4: 重新运行测试并确认通过**

Run: `flutter test test/pages/logs_screen_test.dart --reporter compact`

---

## Chunk 7: 最终验证

### Task 11: 运行静态检查

**Files:**
- No new files.

- [ ] **Step 1: 运行分析器**

Run: `flutter analyze`

### Task 12: 运行针对性回归

**Files:**
- No new files.

- [ ] **Step 1: 运行主题与页面相关测试**

Run: `flutter test test/models test/services test/features/settings test/features/tagging test/features/workbench test/pages test/widgets --reporter compact`

### Task 13: 运行完整测试

**Files:**
- No new files.

- [ ] **Step 1: 运行完整测试套件**

Run: `flutter test --reporter compact`

### Task 14: 运行桌面端人工冒烟

**Files:**
- No new files.

- [ ] **Step 1: 启动应用**

Run: `flutter run -d windows`

- [ ] **Step 2: 人工检查**

确认：

- 默认进入浅色主题
- 通用设置中可切换主题模式
- 导航层、设置页、转发工作台、标签工作台、日志页风格统一
- 深色模式可切换且无明显对比或溢出问题

- [ ] **Step 3: 关闭应用**
