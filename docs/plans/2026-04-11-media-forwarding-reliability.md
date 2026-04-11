# 媒体预览、转发可靠性与错误治理 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复音频组播放、图片组布局、跨页媒体组拆分、标签工作台空白、错误提醒反复出现以及主题不一致问题。

**Architecture:** 以测试驱动方式补齐媒体刷新、分页聚合、标签工作台生命周期和恢复事务治理。保持“转发工作台”和“标签工作台”业务职责分离，只复用共享工作台能力，不重新耦合到单一 coordinator。

**Tech Stack:** Flutter, GetX, SharedPreferences, TDLib adapter, flutter_test

---

### Task 1: 覆盖当前缺陷的失败测试

**Files:**
- Modify: `test/features/pipeline/application/pipeline_media_controller_test.dart`
- Modify: `test/widgets/message_viewer_card_test.dart`
- Modify: `test/services/telegram_service_test.dart`
- Modify: `test/features/tagging/application/tagging_coordinator_test.dart`
- Create: `test/widgets/app_error_panel_test.dart`

**Step 1: 写音频组、图片组、跨页媒体组、标签工作台生命周期、错误面板的新失败测试**

**Step 2: 运行这些测试确认按预期失败**

Run: `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/widgets/message_viewer_card_test.dart test/services/telegram_service_test.dart test/features/tagging/application/tagging_coordinator_test.dart test/widgets/app_error_panel_test.dart`

Expected: FAIL，且失败点分别指向当前缺失行为。

**Step 3: 最小实现通过测试**

**Step 4: 重新运行同一批测试确认转绿**

**Step 5: 保持代码整洁，必要时提取小函数**

### Task 2: 修复媒体预览链路

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_media.dart`
- Modify: `lib/app/shared/presentation/widgets/message_preview_image_gallery.dart`

**Step 1: 让多音频组按目标 track 判断刷新完成**

**Step 2: 让多图组走 mosaic 布局**

**Step 3: 让图片 tile 支持按 index 打开 gallery**

**Step 4: 跑相关 widget 与 controller 测试**

Run: `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/widgets/message_viewer_card_test.dart`

Expected: PASS

### Task 3: 修复跨页媒体组拆分

**Files:**
- Modify: `lib/app/services/telegram_message_reader.dart`
- Modify: `lib/app/services/message_history_paginator.dart`
- Modify: `test/services/telegram_service_test.dart`

**Step 1: 在读取页尾 album 时继续向后补齐消息**

**Step 2: 保证 latestFirst / oldestFirst 都不会重复消息或死循环**

**Step 3: 跑服务层测试**

Run: `flutter test test/services/telegram_service_test.dart`

Expected: PASS

### Task 4: 补齐标签工作台生命周期

**Files:**
- Modify: `lib/app/features/tagging/application/tagging_coordinator.dart`
- Modify: `lib/app/core/di/tagging_module.dart`
- Modify: `test/features/tagging/application/tagging_coordinator_test.dart`
- Modify: `test/pages/tagging_page_test.dart`

**Step 1: 接入 auth/connection/settings 监听与自动抓取**

**Step 2: 设置变更时重置并重新加载**

**Step 3: 验证 Saved Messages 场景可正常拉取**

**Step 4: 跑标签工作台相关测试**

Run: `flutter test test/features/tagging/application/tagging_coordinator_test.dart test/pages/tagging_page_test.dart`

Expected: PASS

### Task 5: 重构错误治理与主题一致性

**Files:**
- Modify: `lib/app/shared/errors/app_error_controller.dart`
- Modify: `lib/app/shared/presentation/widgets/app_error_panel.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_recovery_service.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Modify: `lib/app/features/settings/presentation/settings_screen.dart`
- Modify: `lib/app/shared/presentation/widgets/status_badge.dart`
- Modify: `test/widgets/app_error_panel_test.dart`
- Modify: `test/pages/settings_page_test.dart`

**Step 1: 将可持久化人工核查项从全局错误历史中分离**

**Step 2: 提供清除/标记处理入口**

**Step 3: 清理设置页与错误面板里的硬编码色值**

**Step 4: 跑错误面板与设置页测试**

Run: `flutter test test/widgets/app_error_panel_test.dart test/pages/settings_page_test.dart`

Expected: PASS

### Task 6: 完整验证

**Files:**
- Modify: `docs/plans/2026-04-11-media-forwarding-reliability-design.md`
- Modify: `docs/plans/2026-04-11-media-forwarding-reliability.md`

**Step 1: 运行本次涉及的完整测试集**

Run: `flutter test test/features/pipeline/application/pipeline_media_controller_test.dart test/widgets/message_viewer_card_test.dart test/services/telegram_service_test.dart test/features/tagging/application/tagging_coordinator_test.dart test/pages/tagging_page_test.dart test/widgets/app_error_panel_test.dart test/pages/settings_page_test.dart`

Expected: PASS

**Step 2: 运行静态检查**

Run: `flutter analyze`

Expected: 0 issues

**Step 3: 记录实际结果，如有失败则继续修复，不做成功宣称**
