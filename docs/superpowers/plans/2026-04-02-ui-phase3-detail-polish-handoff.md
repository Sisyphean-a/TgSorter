# UI Phase 3 Detail Polish Handoff

> **For the next agent session:** Read this file first, then continue implementation directly. The user has already approved the direction summarized here. Do not restart broad UI brainstorming unless you hit a real conflict or hidden risk. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在已完成的前两轮基础上，继续完成 UI 第三阶段的细节打磨，直到整体界面达到统一、顺滑、精致、易用的完成态。

**Current Status:** 第一轮核心 UI 重构已完成；第二轮消息预览结构治理已完成。当前代码可运行、测试通过、结构明显优于最初状态，但仍缺少一轮系统性的细节打磨。

**Guardrails:**
- 保持“体验优先”，不要为了设计感牺牲分类效率。
- 不新增 silent fallback，不掩盖错误。
- 不改分类业务流程，不重写 `PipelineController` 主流程。
- 允许做轻量结构收口，但第三阶段重点是细节打磨，不是新一轮大拆分。

**Tech Stack:** Flutter, Dart, GetX, Material 3, flutter_test

---

## 1. 已完成内容

以下工作已经完成，不需要重复做：

### 第一轮

- 建立统一主题系统：
  - `lib/app/theme/app_tokens.dart`
  - `lib/app/theme/app_theme.dart`
- 建立统一页面壳层与品牌工具栏：
  - `lib/app/widgets/app_shell.dart`
  - `lib/app/widgets/brand_app_bar.dart`
  - `lib/app/widgets/status_badge.dart`
- 完成桌面端工作台重构：
  - `lib/app/pages/pipeline_page.dart`
  - `lib/app/pages/pipeline_desktop_view.dart`
  - `lib/app/pages/pipeline_desktop_panels.dart`
  - `lib/app/widgets/workspace_panel.dart`
  - `lib/app/widgets/classification_action_group.dart`
- 完成移动端单手快速流：
  - `lib/app/pages/pipeline_mobile_view.dart`
  - `lib/app/widgets/mobile_action_tray.dart`
- 完成设置页工作区化：
  - `lib/app/pages/settings_page.dart`
  - `lib/app/widgets/settings_section_card.dart`
  - `lib/app/widgets/sticky_action_bar.dart`
  - `lib/app/widgets/app_error_panel.dart`

### 第二轮

- 完成消息预览链路拆分：
  - `lib/app/widgets/message_viewer_card.dart`
  - `lib/app/widgets/message_preview_content.dart`
  - `lib/app/widgets/message_preview_text.dart`
  - `lib/app/widgets/message_preview_link.dart`
  - `lib/app/widgets/message_preview_media.dart`
  - `lib/app/widgets/message_preview_audio.dart`
  - `lib/app/widgets/message_preview_helpers.dart`

### 已通过验证

- `flutter test`
- `dart analyze lib test`

---

## 2. 用户已经明确确认过的设计方向

这些是已经确认过的决策，不需要再问一遍：

- 整体气质：`品牌感强的创意工具`
- 但核心原则：`体验优先，不要花里胡哨，不要影响分类效率`
- 信息密度：`均衡型`
- 桌面端：`双栏工作台`
- 手机端：`单手快速流`
- 第二轮结构治理：`均衡拆分`
- 第二轮重点：`消息预览链路`
- 第二轮拆分策略：`按预览领域拆分`
- 第二轮改动边界：`拆结构 + 小幅顺手优化`

所以第三阶段不应再回头讨论这些基础方向。

---

## 3. 第三阶段建议目标

第三阶段的定义不是大改结构，而是把现有统一语言打磨到“像成品”的程度。

建议目标分为 4 块：

### A. 认证页统一风格

优先级最高。当前主工作台和设置页已经是一套语言，认证页如果仍然偏旧，会造成明显割裂。

优先检查：

- `lib/app/pages/auth_page.dart`

目标：

- 接入 `AppShell` / `BrandAppBar` 或等价统一壳层
- 统一输入框、按钮、状态提示、加载状态
- 保留登录流程清晰性，不做复杂装饰

### B. 弹窗与表单控件统一

当前主页面已成型，但这些局部控件仍可能保留默认 Material 味道：

- `AlertDialog`
- `DropdownButtonFormField`
- `TextField` / `TextFormField`
- `SnackBar`
- 局部 `Chip` / 次按钮 / 危险按钮

目标：

- 统一圆角、边框、背景层级、按钮层级
- 统一高风险动作的视觉语言
- 统一保存成功 / 保存失败 / 链接失败等反馈表现

### C. 交互动效与按钮反馈

只做轻量、明确、可预期的动效：

- 页面切换或面板切换的轻微过渡
- 按钮按压反馈
- 卡片状态变化反馈
- 展开收起的局部过渡

不要做：

- 大位移
- 炫技动画
- 影响效率的长时长效果

### D. 真机手感微调

这是最后收口阶段最值钱的工作：

- 桌面端连续分类时的视线移动是否顺畅
- 手机端底部托盘是否真的处于拇指热区
- 长文本、多媒体组、窄屏、错误提示时是否出现拥挤或节奏断裂
- 重点按钮是否一眼能看懂

---

## 4. 推荐执行顺序

建议严格按这个顺序推进：

### Task 1: 认证页统一风格

优先处理：

- `lib/app/pages/auth_page.dart`

如果需要新增共用小组件，可放入：

- `lib/app/widgets/`

完成标准：

- 认证页明显接入当前主题语言
- 视觉上不再与工作台/设置页割裂
- 登录流程清晰，不花哨

### Task 2: 弹窗与表单控件统一

重点检查：

- `lib/app/pages/settings_page.dart`
- `lib/app/pages/settings_page_parts.dart`
- `lib/app/pages/settings_sections.dart`
- `lib/app/pages/settings_common_editors.dart`
- `lib/app/widgets/settings_section_card.dart`
- `lib/app/widgets/sticky_action_bar.dart`
- `lib/app/pages/auth_page.dart`

完成标准：

- 下拉、输入框、弹窗、提示条统一成一套气质
- 危险操作和普通操作层级更清楚

### Task 3: 工作台微交互打磨

重点检查：

- `lib/app/pages/pipeline_page.dart`
- `lib/app/pages/pipeline_desktop_view.dart`
- `lib/app/pages/pipeline_mobile_view.dart`
- `lib/app/widgets/classification_action_group.dart`
- `lib/app/widgets/mobile_action_tray.dart`
- `lib/app/widgets/message_viewer_card.dart`
- `lib/app/widgets/message_preview_*`

完成标准：

- 分类按钮反馈更明确
- 卡片层级和局部间距更自然
- 状态切换时界面更顺

### Task 4: 回归与微调

执行：

- 跑现有全部测试
- 跑 `dart analyze lib test`
- 根据失败点或明显违和处做最后收口

---

## 5. 当前最值得关注的文件

新会话里优先阅读这些文件：

### 全局基础

- `lib/app/theme/app_tokens.dart`
- `lib/app/theme/app_theme.dart`
- `lib/app/widgets/app_shell.dart`
- `lib/app/widgets/brand_app_bar.dart`
- `lib/app/widgets/status_badge.dart`

### 工作台

- `lib/app/pages/pipeline_page.dart`
- `lib/app/pages/pipeline_desktop_view.dart`
- `lib/app/pages/pipeline_mobile_view.dart`
- `lib/app/widgets/classification_action_group.dart`
- `lib/app/widgets/mobile_action_tray.dart`

### 设置页

- `lib/app/pages/settings_page.dart`
- `lib/app/pages/settings_sections.dart`
- `lib/app/pages/settings_page_parts.dart`
- `lib/app/widgets/settings_section_card.dart`
- `lib/app/widgets/sticky_action_bar.dart`

### 消息预览

- `lib/app/widgets/message_viewer_card.dart`
- `lib/app/widgets/message_preview_content.dart`
- `lib/app/widgets/message_preview_text.dart`
- `lib/app/widgets/message_preview_link.dart`
- `lib/app/widgets/message_preview_media.dart`
- `lib/app/widgets/message_preview_audio.dart`
- `lib/app/widgets/message_preview_helpers.dart`

### 认证页

- `lib/app/pages/auth_page.dart`

---

## 6. 测试与验证要求

第三阶段完成前至少执行：

```bash
flutter test
dart analyze lib test
```

如果只做认证页或局部样式，至少补查相关测试文件：

- `test/pages/pipeline_layout_test.dart`
- `test/pages/pipeline_mobile_view_test.dart`
- `test/pages/settings_page_test.dart`
- `test/widgets/message_viewer_card_test.dart`
- `test/widgets/app_shell_theme_test.dart`
- `test/widget_test.dart`

---

## 7. 对下一位 agent 的直接指令

如果你是新对话中的 agent，请按以下方式继续：

1. 先阅读本文件。
2. 先阅读第 5 节列出的关键文件。
3. 不要重新做大范围 brainstorm；用户已经确认过方向。
4. 直接从 `认证页统一风格` 开始做第三阶段。
5. 采用 TDD 或至少先补失败测试再改实现。
6. 完成一块就跑局部测试，最后跑全量测试和 `dart analyze`。
7. 除非遇到真实冲突，否则不要回退到“大改结构”的方向。

---

## 8. 相关文档

- 第一轮总设计：
  - `docs/superpowers/specs/2026-04-02-overall-ui-redesign-design.md`
- 第一轮计划：
  - `docs/superpowers/plans/2026-04-02-overall-ui-redesign.md`
- 第二轮设计：
  - `docs/superpowers/specs/2026-04-02-message-preview-structure-refactor-design.md`
- 第二轮计划：
  - `docs/superpowers/plans/2026-04-02-message-preview-structure-refactor.md`

---

## 9. 当前结论

可以直接进入 `第三阶段：细节打磨`。

最推荐的起点是：

- 先做 `auth_page.dart` 的统一风格接入
- 然后做弹窗、表单、下拉、提示条的统一
- 最后做工作台细节反馈与真机手感微调
