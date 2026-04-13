# Telegram 风格二层设置重构 TODO

> **For CodexPotter:** 先阅读 `docs/codexpotter/2026-04-13-telegram-settings-two-level-design.md`，本文件是执行清单，不是需求讨论区。禁止把任务降级为“单页换皮”。

**Goal:** 把当前设置界面重构为 Telegram 官方风格的二层设置体系：一级目录页，二级详情页，移除现有单页长列表和底部保存条。

**Architecture:** 复用现有 `SettingsCoordinator` 持久化能力，但引入设置页内部二层导航状态与页面级草稿会话。设置首页只负责导航，二级详情页分别承载转发、标签、连接与网络、外观、快捷键五个领域的编辑与保存。

**Tech Stack:** Flutter, Dart, GetX, flutter_test

---

## 文件结构

- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
  - 让设置页 AppBar 感知一级/二级导航状态。
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
  - 改为设置模块挂载入口，不再直接承载旧单页结构。
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
  - 重构为一级/二级页面切换容器，必要时拆小。
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
  - 输出各二级页的内容块，而不是首页直出全部内容。
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
  - 将现有编辑器改造成适配 Telegram 行式布局的轻量编辑器。
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
  - 分类、会话刷新、未保存提示等组件迁移到新结构。
- Modify: `lib/app/features/settings/presentation/tag_group_editor.dart`
  - 改为适配 `标签` 二级页，不再像大块表单卡片。
- Modify: `lib/app/theme/app_tokens.dart`
  - 增加设置页 Telegram 风格令牌。
- Modify: `lib/app/theme/app_theme.dart`
  - 增加设置页相关主题映射，避免工作台和设置页视觉耦合。
- Create: `lib/app/features/settings/application/settings_navigation_controller.dart`
  - 管理 `home / forwarding / tagging / connection / appearance / shortcuts`。
- Create: `lib/app/features/settings/application/settings_page_draft_session.dart`
  - 管理二级页本地草稿、脏状态、放弃逻辑。
- Create: `lib/app/features/settings/presentation/settings_app_bar.dart`
  - Telegram 风格一级/二级设置顶栏。
- Create: `lib/app/features/settings/presentation/settings_home_page.dart`
  - 设置首页，仅渲染目录项。
- Create: `lib/app/features/settings/presentation/settings_detail_page.dart`
  - 二级详情页骨架，承载标题、保存、返回确认。
- Create: `lib/app/features/settings/presentation/settings_telegram_tiles.dart`
  - Telegram 风格导航行、开关行、摘要行、分组标题等基础组件。
- Test: `test/pages/settings_page_test.dart`
  - 锁定一级/二级导航、AppBar、保存行为。
- Create: `test/features/settings/application/settings_navigation_controller_test.dart`
  - 锁定设置页二层导航状态。
- Create: `test/features/settings/application/settings_page_draft_session_test.dart`
  - 锁定页面本地草稿与脏状态。
- Modify: `test/widgets/app_shell_theme_test.dart`
  - 锁定设置页 Telegram 风格令牌和列表组件。

---

## Chunk 1: 锁定二层信息架构

### Task 1: 为设置页新增二层导航测试

**Files:**
- Modify: `test/pages/settings_page_test.dart`
- Create: `test/features/settings/application/settings_navigation_controller_test.dart`

- [ ] **Step 1: 写失败测试，断言一级首页只出现目录行**

必须断言首页存在：

- `转发`
- `标签`
- `连接与网络`
- `外观`
- `快捷键`

并断言首页**不存在**：

- 代理输入框
- 标签输入框
- 分类下拉框
- 底部 `保存更改` / `放弃更改`

- [ ] **Step 2: 写失败测试，断言点击目录行会进入二级页**

覆盖：

- 标题从 `设置` 切到对应详情页标题。
- 出现返回箭头。
- 二级页内容只属于当前领域。

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/features/settings/application/settings_navigation_controller_test.dart
```

Expected:

- FAIL，原因是当前仍是单页设置，缺少二层导航状态。

### Task 2: 实现二层导航状态与页面骨架

**Files:**
- Create: `lib/app/features/settings/application/settings_navigation_controller.dart`
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Create: `lib/app/features/settings/presentation/settings_home_page.dart`
- Create: `lib/app/features/settings/presentation/settings_detail_page.dart`

- [ ] **Step 1: 实现二层导航枚举和控制器**

最小边界：

```dart
enum SettingsRoute {
  home,
  forwarding,
  tagging,
  connection,
  appearance,
  shortcuts,
}
```

- [ ] **Step 2: 将设置页重构为“首页 / 详情页”切换容器**

要求：

- 首页只渲染目录。
- 详情页只渲染当前 route 对应内容。
- 禁止三级 route。

- [ ] **Step 3: 重新运行测试**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/features/settings/application/settings_navigation_controller_test.dart
```

Expected:

- PASS

---

## Chunk 2: 重建 Telegram 风格顶栏与列表骨架

### Task 3: 为设置页顶栏和列表组件写失败测试

**Files:**
- Modify: `test/widgets/app_shell_theme_test.dart`
- Modify: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 写失败测试，断言设置首页与二级页使用 Telegram 风格顶栏**

覆盖：

- 一级页标题仅为 `设置`
- 二级页显示返回箭头
- 二级页 dirty 时显示 `保存`
- 不再显示 `草稿未保存` / `已保存` badge

- [ ] **Step 2: 写失败测试，断言列表组件不再使用卡片式分组和底部保存条**

覆盖：

- 不出现 `StickyActionBar`
- 不出现大描边卡片式 `SettingsListSection`
- 行之间使用细分割线

- [ ] **Step 3: 运行测试确认失败**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/widgets/app_shell_theme_test.dart
```

Expected:

- FAIL

### Task 4: 实现 Telegram 风格设置骨架

**Files:**
- Create: `lib/app/features/settings/presentation/settings_app_bar.dart`
- Create: `lib/app/features/settings/presentation/settings_telegram_tiles.dart`
- Modify: `lib/app/theme/app_tokens.dart`
- Modify: `lib/app/theme/app_theme.dart`
- Modify: `lib/app/features/shell/presentation/main_shell_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_page.dart`

- [ ] **Step 1: 增加设置页专用视觉令牌**

至少包括：

- 顶栏蓝
- 页面浅灰背景
- 行背景
- 分割线
- 主/副文本
- 危险动作

- [ ] **Step 2: 实现 Telegram 风格顶栏与基础 tile**

至少提供：

- `SettingsNavigationTile`
- `SettingsValueTile`
- `SettingsSwitchTile`
- `SettingsSectionHeader`

- [ ] **Step 3: 让 `MainShellPage` 的设置 AppBar 跟随设置内部 route 变化**

要求：

- 首页显示 `设置`
- 二级页显示当前领域标题
- 二级页仅在脏状态下暴露 `保存`

- [ ] **Step 4: 重新运行测试**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/widgets/app_shell_theme_test.dart
```

Expected:

- PASS

---

## Chunk 3: 用页面本地草稿替换全局底部保存条

### Task 5: 为页面本地草稿会话写失败测试

**Files:**
- Create: `test/features/settings/application/settings_page_draft_session_test.dart`
- Modify: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 写失败测试，锁定二级页本地草稿行为**

覆盖：

- 进入 `转发` 页后修改不会立刻写回 `savedSettings`
- 二级页 dirty 时出现 `保存`
- 返回时弹出 `继续编辑 / 放弃更改`
- 放弃后不污染其他页

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
flutter test test/features/settings/application/settings_page_draft_session_test.dart test/pages/settings_page_test.dart
```

Expected:

- FAIL，当前只有全局底部保存条语义。

### Task 6: 实现页面本地草稿与返回确认

**Files:**
- Create: `lib/app/features/settings/application/settings_page_draft_session.dart`
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
- Modify: `lib/app/features/settings/presentation/settings_detail_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`

- [ ] **Step 1: 为二级页引入本地草稿会话**

要求：

- 页面进入时从 `savedSettings` 派生。
- 页面离开不自动污染全局。
- 保存时才提交到 `SettingsCoordinator`。

- [ ] **Step 2: 删除底部保存条依赖**

要求：

- 页面不再依赖 `StickyActionBar`
- 不再依赖首页全局未保存 banner

- [ ] **Step 3: 为二级页实现返回确认**

要求：

- 未修改直接返回
- 已修改弹确认
- 保存成功后返回首页或保持当前页，二选一后保持一致

- [ ] **Step 4: 重新运行测试**

Run:

```powershell
flutter test test/features/settings/application/settings_page_draft_session_test.dart test/pages/settings_page_test.dart
```

Expected:

- PASS

---

## Chunk 4: 迁移“转发”二级页

### Task 7: 为转发页写失败测试

**Files:**
- Modify: `test/pages/settings_page_test.dart`
- Modify: `test/features/settings/application/settings_coordinator_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：

- `转发` 二级页展示：
  - 来源会话
  - 消息拉取方向
  - 无引用转发
  - 批处理条数
  - 节流毫秒
  - 预览预加载数量
  - 分类目标管理
- 分类新增/删除仍显式暴露错误
- 页面保存后才真正提交

- [ ] **Step 2: 运行测试确认失败**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/features/settings/application/settings_coordinator_test.dart
```

Expected:

- FAIL

### Task 8: 实现转发二级页

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`

- [ ] **Step 1: 把现有转发相关编辑器嵌入 `转发` 二级页**

要求：

- 统一成 Telegram 风格行式布局
- 分类管理留在本页内
- 不跳第三层 route

- [ ] **Step 2: 收敛分类区视觉**

要求：

- 不再像独立大卡片
- 目标会话切换、删除动作都服从列表行语义

- [ ] **Step 3: 重新运行测试**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/features/settings/application/settings_coordinator_test.dart
```

Expected:

- PASS

---

## Chunk 5: 迁移“标签”“连接与网络”“外观”“快捷键”二级页

### Task 9: 为剩余四个二级页写失败测试

**Files:**
- Modify: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 为 `标签` 页写失败测试**

覆盖：

- 标签来源会话
- 默认标签组增删
- 错误显式暴露

- [ ] **Step 2: 为 `连接与网络` 页写失败测试**

覆盖：

- 代理字段
- 刷新会话列表
- 代理保存失败或重启失败提示仍然保留

- [ ] **Step 3: 为 `外观` 与 `快捷键` 页写失败测试**

覆盖：

- 主题模式迁移到 `外观`
- 快捷键绑定和恢复默认迁移到 `快捷键`

- [ ] **Step 4: 运行测试确认失败**

Run:

```powershell
flutter test test/pages/settings_page_test.dart
```

Expected:

- FAIL

### Task 10: 实现剩余四个二级页

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Modify: `lib/app/features/settings/presentation/settings_common_editors.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Modify: `lib/app/features/settings/presentation/tag_group_editor.dart`

- [ ] **Step 1: 实现 `标签` 二级页**

要求：

- 标签组编辑仍在本页完成
- 不新增三级路由

- [ ] **Step 2: 实现 `连接与网络` 二级页**

要求：

- 代理输入改为轻量分组
- 刷新会话列表作为列表动作行

- [ ] **Step 3: 实现 `外观` 与 `快捷键` 二级页**

要求：

- 外观页只承担主题模式
- 快捷键页承载所有绑定与恢复默认

- [ ] **Step 4: 重新运行测试**

Run:

```powershell
flutter test test/pages/settings_page_test.dart
```

Expected:

- PASS

---

## Chunk 6: 删除旧结构并做回归

### Task 11: 清理旧的单页设置残留

**Files:**
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Modify: `lib/app/features/settings/presentation/settings_list_section.dart`
- Modify: `lib/app/shared/presentation/widgets/sticky_action_bar.dart`

- [ ] **Step 1: 确认旧结构不再被引用**

必须清理：

- 单页长列表拼装逻辑
- 底部 `StickyActionBar` 设置依赖
- “当前有未保存更改”首页提示残留

- [ ] **Step 2: 如果旧组件已完全失效，删除或去引用**

要求：

- 只在新结构稳定后处理
- 不保留死码

- [ ] **Step 3: 运行 analyzer**

Run:

```powershell
flutter analyze
```

Expected:

- PASS

### Task 12: 回归测试与人工验收

**Files:**
- No new files.

- [ ] **Step 1: 运行设置相关测试**

Run:

```powershell
flutter test test/pages/settings_page_test.dart test/features/settings test/widgets/app_shell_theme_test.dart
```

Expected:

- PASS

- [ ] **Step 2: 运行全量测试**

Run:

```powershell
flutter test
```

Expected:

- PASS

- [ ] **Step 3: 手工验收**

检查：

- 首页只显示目录行
- 二级页标题、返回、保存动作正确
- 不存在底部保存条
- 分类和标签编辑不产生三级页面
- 保存失败、代理重启失败都有明确反馈
- 视觉整体接近 Telegram 官方设置，不残留旧卡片风格

## 交付口径

只有同时满足以下条件，才允许宣称完成：

1. 已经变成真正的二层设置结构。
2. 已经移除底部 `StickyActionBar`。
3. 一级页不再直接展示复杂编辑器。
4. 二级页按领域拆分完成。
5. 自动化测试和人工验收都通过。
