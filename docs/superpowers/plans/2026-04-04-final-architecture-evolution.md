# Final Architecture Evolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 彻底移除兼容层与 legacy 语义，让 `features/*` 成为唯一真实入口，并将跨 feature 共享部件归位到 `shared/`。

**Architecture:** 先统一 `Auth/Pipeline/Settings` 的 coordinator 命名与主调用链，再切换 DI、路由、页面和测试到最终路径，随后删除 `controllers/pages` 兼容壳与 `*_legacy.dart`，最后做 `shared` 归位和文档/回归收口。整个过程坚持“先编译通过，再删旧层，再迁共享”的顺序，避免同时混改结构与行为。

**Tech Stack:** Flutter、Dart 3.11、GetX、flutter_test

---

## File Map

**Create**
- `lib/app/shared/presentation/widgets/app_shell.dart`
- `lib/app/shared/presentation/widgets/brand_app_bar.dart`
- `lib/app/shared/presentation/widgets/status_badge.dart`
- `lib/app/shared/presentation/widgets/workspace_panel.dart`
- `lib/app/shared/presentation/widgets/sticky_action_bar.dart`
- `lib/app/shared/presentation/widgets/message_viewer_card.dart`
- `lib/app/shared/presentation/formatters/pipeline_log_formatter.dart`

**Modify**
- `lib/app/core/di/app_bindings.dart`
- `lib/app/core/di/auth_module.dart`
- `lib/app/core/di/pipeline_module.dart`
- `lib/app/core/di/settings_module.dart`
- `lib/app/core/routing/app_routes.dart`
- `lib/app/app.dart`
- `lib/app/bootstrap_app.dart`
- `lib/app/controllers/app_error_controller.dart`
- `lib/app/features/auth/application/auth_coordinator.dart`
- `lib/app/features/auth/presentation/auth_page.dart`
- `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- `lib/app/features/pipeline/application/pipeline_action_service.dart`
- `lib/app/features/pipeline/application/pipeline_media_refresh_service.dart`
- `lib/app/features/pipeline/application/pipeline_recovery_service.dart`
- `lib/app/features/pipeline/application/remaining_count_service.dart`
- `lib/app/features/pipeline/application/pipeline_settings_reader.dart`
- `lib/app/features/pipeline/presentation/pipeline_page.dart`
- `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
- `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
- `lib/app/features/pipeline/presentation/pipeline_desktop_panels.dart`
- `lib/app/features/settings/application/settings_coordinator.dart`
- `lib/app/features/settings/presentation/settings_page.dart`
- `lib/app/features/settings/presentation/settings_page_parts.dart`
- `lib/app/features/settings/presentation/settings_sections.dart`
- `lib/app/widgets/app_error_panel.dart`
- `lib/app/widgets/classification_action_group.dart`
- `lib/app/widgets/mobile_action_tray.dart`
- `lib/app/widgets/pipeline_layout_switch.dart`
- `lib/app/widgets/settings_section_card.dart`
- `lib/app/widgets/shortcut_bindings_editor.dart`
- `lib/app/models/app_settings.dart`
- `docs/ARCHITECTURE.md`

**Delete**
- `lib/app/controllers/auth_controller.dart`
- `lib/app/controllers/pipeline_controller.dart`
- `lib/app/controllers/pipeline_settings_provider.dart`
- `lib/app/controllers/settings_controller.dart`
- `lib/app/pages/auth_page.dart`
- `lib/app/pages/pipeline_desktop_panels.dart`
- `lib/app/pages/pipeline_desktop_view.dart`
- `lib/app/pages/pipeline_log_formatter.dart`
- `lib/app/pages/pipeline_mobile_view.dart`
- `lib/app/pages/pipeline_page.dart`
- `lib/app/pages/settings_category_dialog.dart`
- `lib/app/pages/settings_common_editors.dart`
- `lib/app/pages/settings_page.dart`
- `lib/app/pages/settings_page_parts.dart`
- `lib/app/pages/settings_sections.dart`
- `lib/app/features/auth/application/auth_controller_legacy.dart`
- `lib/app/features/pipeline/application/pipeline_controller_legacy.dart`
- `lib/app/features/pipeline/application/pipeline_settings_provider.dart`
- `lib/app/features/settings/application/settings_controller_legacy.dart`

**Test**
- `test/features/pipeline/application/pipeline_coordinator_test.dart`
- `test/features/settings/application/settings_coordinator_test.dart`
- `test/pages/auth_page_test.dart`
- `test/pages/pipeline_layout_test.dart`
- `test/pages/pipeline_mobile_view_test.dart`
- `test/pages/settings_page_test.dart`
- `test/integration/auth_pipeline_flow_test.dart`
- `test/controllers/pipeline_controller_test.dart`
- `test/controllers/settings_controller_test.dart`
- `test/widgets/message_viewer_card_test.dart`
- `test/widgets/app_shell_theme_test.dart`

### Task 1: 统一 coordinator 命名并吸收 legacy 实现

**Files:**
- Modify: `lib/app/features/auth/application/auth_coordinator.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
- Modify: `lib/app/core/di/auth_module.dart`
- Modify: `lib/app/core/di/pipeline_module.dart`
- Modify: `lib/app/core/di/settings_module.dart`
- Test: `test/features/pipeline/application/pipeline_coordinator_test.dart`
- Test: `test/features/settings/application/settings_coordinator_test.dart`

- [ ] **Step 1: 在 coordinator 测试中加入最终命名与入口语义的失败断言**

```dart
test('PipelineCoordinator is the concrete page-facing runtime entry', () {
  final coordinator = PipelineCoordinator(
    runtimeState: PipelineRuntimeState(),
    navigation: navigation,
    actions: actions,
    recovery: recovery,
    mediaRefresh: mediaRefresh,
    remainingCount: remainingCount,
  );

  expect(coordinator.currentMessage, isA<Rxn<PipelineMessage>>());
});
```

```dart
test('SettingsCoordinator is the concrete page-facing settings entry', () {
  final coordinator = SettingsCoordinator(repository, sessions);

  expect(coordinator.savedSettings, isA<Rx<AppSettings>>());
});
```

- [ ] **Step 2: 运行聚焦测试确认当前仍依赖旧 controller/legacy 语义**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_coordinator_test.dart`
Expected: FAIL 或需要补充最终入口断言

Run: `timeout 60s flutter test test/features/settings/application/settings_coordinator_test.dart`
Expected: FAIL 或需要补充最终入口断言

- [ ] **Step 3: 将 legacy controller 中页面面向的应用层逻辑吸收到 coordinator**

```dart
class AuthCoordinator extends GetxController {
  AuthCoordinator(this._service, this._errors, this._settings);

  final AuthGateway _service;
  final AppErrorController _errors;
  final SettingsCoordinator _settings;
  final stage = AuthStage.loading.obs;
  final loading = false.obs;
}
```

```dart
class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required this.runtimeState,
    required this.navigation,
    required this.actions,
    required this.recovery,
    required this.mediaRefresh,
    required this.remainingCount,
    required MessageReadGateway messages,
    required PipelineSettingsReader settings,
    required AppErrorController errors,
  });
}
```

```dart
class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(
    this._repository,
    this._sessions, {
    AuthGateway? auth,
    ...
  });
}
```

- [ ] **Step 4: 更新 DI 仅注册 coordinator 真实入口**

```dart
Get.put(
  AuthCoordinator(
    Get.find<AuthGateway>(),
    Get.find<AppErrorController>(),
    Get.find<SettingsCoordinator>(),
  ),
  permanent: true,
);
```

- [ ] **Step 5: 运行 application 聚焦验证**

Run: `timeout 60s dart analyze lib/app/features/auth/application lib/app/features/pipeline/application lib/app/features/settings/application lib/app/core/di`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_coordinator_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/settings/application/settings_coordinator_test.dart`
Expected: PASS

### Task 2: 切换路由、页面与页面测试到最终 coordinator 主链

**Files:**
- Modify: `lib/app/core/routing/app_routes.dart`
- Modify: `lib/app/features/auth/presentation/auth_page.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_page.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_panels.dart`
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Modify: `lib/app/features/settings/presentation/settings_sections.dart`
- Test: `test/pages/auth_page_test.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/pages/pipeline_mobile_view_test.dart`
- Test: `test/pages/settings_page_test.dart`
- Test: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 先在页面测试中改用 feature 真路径与 coordinator 命名，观察失败**

```dart
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
```

```dart
final auth = AuthCoordinator(service, errors, settings);
await tester.pumpWidget(
  GetMaterialApp(
    home: AuthPage(auth: auth, errors: errors, settings: settings),
  ),
);
```

- [ ] **Step 2: 运行页面测试确认旧 import / 旧类型依赖报错**

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: FAIL，提示旧 controller 或页面路径不再适配

- [ ] **Step 3: 更新路由与页面构造，仅依赖 coordinator**

```dart
GetPage(
  name: AppRoutes.pipeline,
  page: () => PipelinePage(
    pipeline: Get.find<PipelineCoordinator>(),
    settings: Get.find<SettingsCoordinator>(),
    errors: Get.find<AppErrorController>(),
  ),
),
```

- [ ] **Step 4: 批量更新页面测试与 integration 测试到新主链**

```dart
Get.put<SettingsCoordinator>(settings);
Get.put<AuthCoordinator>(auth);
Get.put<PipelineCoordinator>(pipeline);
```

- [ ] **Step 5: 运行页面与集成回归**

Run: `timeout 60s dart analyze lib/app/core/routing lib/app/features/auth/presentation lib/app/features/pipeline/presentation lib/app/features/settings/presentation test/pages test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/pipeline_layout_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/pipeline_mobile_view_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/settings_page_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

### Task 3: 删除兼容壳与 `*_legacy.dart`

**Files:**
- Delete: `lib/app/controllers/*`
- Delete: `lib/app/pages/*`
- Delete: `lib/app/features/auth/application/auth_controller_legacy.dart`
- Delete: `lib/app/features/pipeline/application/pipeline_controller_legacy.dart`
- Delete: `lib/app/features/pipeline/application/pipeline_settings_provider.dart`
- Delete: `lib/app/features/settings/application/settings_controller_legacy.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`
- Modify: `test/controllers/settings_controller_test.dart`

- [ ] **Step 1: 把 controller 测试改到 coordinator 真路径，确保旧壳删除前已有新测试入口**

```dart
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
```

- [ ] **Step 2: 运行 controller 测试确认仍有旧路径依赖**

Run: `timeout 60s flutter test test/controllers`
Expected: FAIL，提示旧 controller 或 provider 路径

- [ ] **Step 3: 删除兼容壳与 legacy 文件，并修正剩余 import**

```bash
rm lib/app/controllers/auth_controller.dart
rm lib/app/controllers/pipeline_controller.dart
rm lib/app/controllers/pipeline_settings_provider.dart
rm lib/app/controllers/settings_controller.dart
rm lib/app/pages/auth_page.dart
...
rm lib/app/features/auth/application/auth_controller_legacy.dart
rm lib/app/features/pipeline/application/pipeline_controller_legacy.dart
rm lib/app/features/settings/application/settings_controller_legacy.dart
```

- [ ] **Step 4: 将剩余实现统一收敛到 coordinator / reader 新路径**

```dart
abstract class PipelineSettingsReader {
  Rx<AppSettings> get settingsStream;
  AppSettings get currentSettings;
  CategoryConfig getCategory(String key);
}
```

- [ ] **Step 5: 运行 analyze 与 controller 回归**

Run: `timeout 60s dart analyze`
Expected: PASS

Run: `timeout 60s flutter test test/controllers`
Expected: PASS 或 controller 目录已被移除

### Task 4: 建立 `shared/` 并迁移真实共享部件

**Files:**
- Create: `lib/app/shared/presentation/widgets/*.dart`
- Create: `lib/app/shared/presentation/formatters/pipeline_log_formatter.dart`
- Modify: `lib/app/features/auth/presentation/auth_page.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_page.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_mobile_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_view.dart`
- Modify: `lib/app/features/pipeline/presentation/pipeline_desktop_panels.dart`
- Modify: `lib/app/features/settings/presentation/settings_page.dart`
- Modify: `lib/app/features/settings/presentation/settings_page_parts.dart`
- Modify: `lib/app/widgets/app_error_panel.dart`
- Modify: `lib/app/widgets/classification_action_group.dart`
- Modify: `lib/app/widgets/mobile_action_tray.dart`
- Modify: `lib/app/widgets/pipeline_layout_switch.dart`
- Modify: `lib/app/widgets/settings_section_card.dart`
- Modify: `lib/app/widgets/shortcut_bindings_editor.dart`
- Test: `test/widgets/message_viewer_card_test.dart`
- Test: `test/widgets/app_shell_theme_test.dart`

- [ ] **Step 1: 先迁最基础的共享 UI 壳组件，并让 widget 测试指向新路径**

```dart
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
```

- [ ] **Step 2: 运行 widget 测试确认旧路径依赖失败**

Run: `timeout 60s flutter test test/widgets/app_shell_theme_test.dart`
Expected: FAIL，提示旧 widget 路径

- [ ] **Step 3: 迁移消息预览与格式化类到 shared**

```dart
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/shared/presentation/formatters/pipeline_log_formatter.dart';
```

- [ ] **Step 4: 更新 feature 页面和剩余 widgets import 到 shared**

```dart
import 'package:tgsorter/app/shared/presentation/widgets/workspace_panel.dart';
import 'package:tgsorter/app/shared/presentation/widgets/sticky_action_bar.dart';
```

- [ ] **Step 5: 运行 widgets/pages 回归**

Run: `timeout 60s dart analyze lib/app/shared lib/app/features lib/app/widgets test/widgets test/pages`
Expected: PASS

Run: `timeout 60s flutter test test/widgets`
Expected: PASS

Run: `timeout 60s flutter test test/pages`
Expected: PASS

### Task 5: 文档收口与最终全量回归

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/superpowers/specs/2026-04-04-final-architecture-evolution-design.md`（如需同步术语）

- [ ] **Step 1: 更新架构文档中的最终目录与依赖关系**

```md
- `features/*` 是唯一真实业务入口
- `shared/` 承担跨 feature 共享展示部件
- 项目中不再保留 `controllers/pages` 兼容层与 `*_legacy.dart`
```

- [ ] **Step 2: 自查仓库中不再存在旧壳与 legacy 引用**

Run: `rg -n "controllers/|pages/|_legacy\\.dart" lib/app test docs`
Expected: 仅文档中的历史描述命中，代码中无命中

- [ ] **Step 3: 执行最终静态检查**

Run: `timeout 60s dart analyze`
Expected: PASS

- [ ] **Step 4: 执行最终关键测试回归**

Run: `timeout 60s flutter test test/features/pipeline/application`
Expected: PASS

Run: `timeout 60s flutter test test/features/settings/application`
Expected: PASS

Run: `timeout 60s flutter test test/services`
Expected: PASS

Run: `timeout 60s flutter test test/pages`
Expected: PASS

Run: `timeout 60s flutter test test/widgets`
Expected: PASS

Run: `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

- [ ] **Step 5: 提交最终架构演化**

```bash
git add lib/app docs test
git commit -m "refactor: complete final architecture evolution"
git push
```

## Self-Review

### Spec coverage

- 删除兼容层：Task 2、Task 3 覆盖页面/路由切换与兼容壳删除。
- 删除 legacy 语义：Task 1、Task 3 覆盖 coordinator 命名收口与 legacy 文件移除。
- 建立 shared：Task 4 覆盖共享 UI 与 formatter 归位。
- 最终唯一真实入口：Task 1 到 Task 3 覆盖 DI、页面、测试主链切换。
- 回归与文档：Task 5 覆盖 analyze、测试与 `ARCHITECTURE.md` 收口。
