# TgSorter Windows Desktop Workspace Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在同一套 Flutter 代码中新增 Windows 桌面双栏工作台与可配置快捷键，同时保持 Android 现有行为不变。

**Architecture:** 页面层按宽度切换 mobile/desktop 布局；业务控制器与 Telegram 服务保持复用。设置模型新增快捷键绑定并由仓储持久化。桌面端通过 `Shortcuts/Actions` 将按键映射到既有流水线操作。

**Tech Stack:** Flutter, Dart, GetX, SharedPreferences, flutter_test

---

## File Map

- Modify: `lib/app/models/app_settings.dart`（新增快捷键配置模型与不可变更新方法）
- Create: `lib/app/models/shortcut_binding.dart`（快捷键动作与按键定义）
- Modify: `lib/app/services/settings_repository.dart`（快捷键配置读写）
- Modify: `lib/app/controllers/settings_controller.dart`（快捷键保存与重置接口）
- Modify: `lib/app/pages/settings_page.dart`（快捷键设置 UI）
- Modify: `lib/app/pages/pipeline_page.dart`（布局分流入口）
- Create: `lib/app/pages/pipeline_mobile_view.dart`（移动端现有布局提取）
- Create: `lib/app/pages/pipeline_desktop_view.dart`（桌面双栏工作台 + 快捷键注册）
- Create: `test/models/app_settings_shortcut_test.dart`
- Create: `test/services/settings_repository_shortcut_test.dart`
- Create: `test/pages/pipeline_layout_test.dart`

## Chunk 1: 快捷键模型与持久化

### Task 1: AppSettings 扩展快捷键模型

**Files:**
- Create: `lib/app/models/shortcut_binding.dart`
- Modify: `lib/app/models/app_settings.dart`
- Test: `test/models/app_settings_shortcut_test.dart`

- [ ] **Step 1: 写失败测试（默认映射、更新映射、重置映射）**
- [ ] **Step 2: 运行 `flutter test test/models/app_settings_shortcut_test.dart`，确认失败**
- [ ] **Step 3: 实现 `ShortcutAction`、`ShortcutBinding` 与 `AppSettings` 新字段/方法**
- [ ] **Step 4: 再次运行该测试，确认通过**
- [ ] **Step 5: 提交本任务变更**

### Task 2: SettingsRepository 快捷键读写

**Files:**
- Modify: `lib/app/services/settings_repository.dart`
- Modify: `lib/app/controllers/settings_controller.dart`
- Test: `test/services/settings_repository_shortcut_test.dart`

- [ ] **Step 1: 写失败测试（保存后可读、非法值回退默认）**
- [ ] **Step 2: 运行 `flutter test test/services/settings_repository_shortcut_test.dart`，确认失败**
- [ ] **Step 3: 实现仓储序列化/反序列化与控制器保存接口**
- [ ] **Step 4: 再次运行该测试，确认通过**
- [ ] **Step 5: 提交本任务变更**

## Chunk 2: 桌面双栏与快捷键交互

### Task 3: 提取移动布局并新增桌面布局

**Files:**
- Modify: `lib/app/pages/pipeline_page.dart`
- Create: `lib/app/pages/pipeline_mobile_view.dart`
- Create: `lib/app/pages/pipeline_desktop_view.dart`
- Test: `test/pages/pipeline_layout_test.dart`

- [ ] **Step 1: 写失败测试（宽屏渲染 desktop 关键节点，窄屏渲染 mobile 关键节点）**
- [ ] **Step 2: 运行 `flutter test test/pages/pipeline_layout_test.dart`，确认失败**
- [ ] **Step 3: 实现布局分流与桌面双栏工作台**
- [ ] **Step 4: 再次运行该测试，确认通过**
- [ ] **Step 5: 提交本任务变更**

### Task 4: 设置页新增快捷键配置

**Files:**
- Modify: `lib/app/pages/settings_page.dart`

- [ ] **Step 1: 增加快捷键配置区（展示映射、编辑、重置）并接入控制器**
- [ ] **Step 2: 在桌面端手动验证设置变更后主页面快捷键即时生效**
- [ ] **Step 3: 提交本任务变更**

## Chunk 3: 全量验证

### Task 5: 回归验证与收尾

**Files:**
- Modify（如需要）: 受影响文件

- [ ] **Step 1: 运行 `flutter test`**
- [ ] **Step 2: 运行 `flutter analyze`**
- [ ] **Step 3: 运行 Windows 启动验证 `flutter run -d windows --dart-define-from-file=.env.local.json`**
- [ ] **Step 4: 修复验证问题并重复验证直至通过**
- [ ] **Step 5: 提交最终变更**
