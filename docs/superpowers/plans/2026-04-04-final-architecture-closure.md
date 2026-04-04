# Final Architecture Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一次性收平 auth / settings / gateway / DI / error system 的剩余结构问题，让项目进入最终稳态架构。

**Architecture:** 保留当前 feature-first 模块化单体方向，不推翻现有主结构。先建立结构化错误流与 capability ports，再按依赖顺序收口 settings 和 auth，随后删除 `TelegramGateway` 与临时桥接，最后统一 DI、路由、页面和文档。整个过程严格采用 TDD 与阶段性回归，避免长时间停留在中间态。

**Tech Stack:** Flutter、Dart 3.11、GetX、flutter_test、shared_preferences

---

## File Map

**Create**
- `lib/app/shared/errors/app_error_event.dart`
- `lib/app/shared/errors/app_error_controller.dart`
- `lib/app/features/auth/application/auth_error_mapper.dart`
- `lib/app/features/auth/application/auth_lifecycle_coordinator.dart`
- `lib/app/features/auth/ports/auth_gateway.dart`
- `lib/app/features/auth/ports/auth_navigation_port.dart`
- `lib/app/features/settings/application/settings_chat_loader.dart`
- `lib/app/features/settings/application/settings_draft_coordinator.dart`
- `lib/app/features/settings/application/settings_persistence_service.dart`
- `lib/app/features/settings/application/settings_restart_policy.dart`
- `lib/app/features/settings/ports/session_query_gateway.dart`
- `lib/app/features/pipeline/ports/classify_gateway.dart`
- `lib/app/features/pipeline/ports/connection_state_gateway.dart`
- `lib/app/features/pipeline/ports/media_gateway.dart`
- `lib/app/features/pipeline/ports/message_read_gateway.dart`
- `lib/app/features/pipeline/ports/recovery_gateway.dart`
- `lib/app/core/routing/getx_auth_navigation_adapter.dart`
- `test/shared/errors/app_error_controller_test.dart`
- `test/features/auth/application/auth_error_mapper_test.dart`
- `test/features/auth/application/auth_lifecycle_coordinator_test.dart`
- `test/features/settings/application/settings_chat_loader_test.dart`
- `test/features/settings/application/settings_draft_coordinator_test.dart`
- `test/features/settings/application/settings_persistence_service_test.dart`
- `test/features/settings/application/settings_restart_policy_test.dart`

**Modify**
- `lib/app/core/di/app_bindings.dart`
- `lib/app/core/di/auth_module.dart`
- `lib/app/core/di/pipeline_module.dart`
- `lib/app/core/di/settings_module.dart`
- `lib/app/core/routing/app_routes.dart`
- `lib/app/features/auth/application/auth_coordinator.dart`
- `lib/app/features/auth/presentation/auth_page.dart`
- `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- `lib/app/features/pipeline/application/pipeline_error_mapper.dart`
- `lib/app/features/pipeline/application/pipeline_gateway_adapters.dart`
- `lib/app/features/pipeline/application/pipeline_feed_controller.dart`
- `lib/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart`
- `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- `lib/app/features/pipeline/application/pipeline_media_refresh_service.dart`
- `lib/app/features/pipeline/application/pipeline_recovery_service.dart`
- `lib/app/features/settings/application/settings_coordinator.dart`
- `lib/app/features/settings/presentation/settings_page.dart`
- `lib/app/features/settings/presentation/settings_page_parts.dart`
- `lib/app/features/settings/presentation/settings_sections.dart`
- `lib/app/features/pipeline/presentation/pipeline_page.dart`
- `lib/app/shared/presentation/widgets/app_error_panel.dart`
- `lib/app/services/telegram_service.dart`
- `docs/ARCHITECTURE.md`
- `test/controllers/pipeline_controller_test.dart`
- `test/controllers/settings_controller_test.dart`
- `test/features/pipeline/application/pipeline_error_mapper_test.dart`
- `test/features/pipeline/application/pipeline_coordinator_test.dart`
- `test/features/settings/application/settings_coordinator_test.dart`
- `test/pages/auth_page_test.dart`
- `test/pages/pipeline_layout_test.dart`
- `test/pages/pipeline_mobile_view_test.dart`
- `test/pages/settings_page_test.dart`
- `test/integration/auth_pipeline_flow_test.dart`
- `test/widgets/app_error_panel_test.dart`

**Delete**
- `lib/app/controllers/app_error_controller.dart`
- `lib/app/features/auth/application/auth_gateway.dart`
- `lib/app/features/settings/application/session_query_gateway.dart`
- `lib/app/features/pipeline/application/classify_gateway.dart`
- `lib/app/features/pipeline/application/media_gateway.dart`
- `lib/app/features/pipeline/application/message_read_gateway.dart`
- `lib/app/features/pipeline/application/recovery_gateway.dart`
- `lib/app/services/telegram_gateway.dart`

**Verify**
- `timeout 60s dart analyze`
- `timeout 60s flutter test test/shared/errors`
- `timeout 60s flutter test test/features/auth/application`
- `timeout 60s flutter test test/features/settings/application`
- `timeout 60s flutter test test/features/pipeline/application`
- `timeout 60s flutter test test/controllers`
- `timeout 60s flutter test test/pages`
- `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
- `timeout 60s flutter test`

### Task 1: 建立结构化错误流与连接状态 port

**Files:**
- Create: `lib/app/shared/errors/app_error_event.dart`
- Create: `lib/app/shared/errors/app_error_controller.dart`
- Create: `lib/app/features/pipeline/ports/connection_state_gateway.dart`
- Create: `test/shared/errors/app_error_controller_test.dart`
- Modify: `lib/app/shared/presentation/widgets/app_error_panel.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_error_mapper.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `test/features/pipeline/application/pipeline_error_mapper_test.dart`
- Modify: `test/widgets/app_error_panel_test.dart`

- [ ] **Step 1: 先写结构化错误失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

void main() {
  test('reportEvent stores structured error as current and history head', () {
    final controller = AppErrorController();
    const event = AppErrorEvent(
      scope: AppErrorScope.pipeline,
      level: AppErrorLevel.error,
      title: '网络异常',
      message: '请检查网络连接后重试',
    );

    controller.reportEvent(event);

    expect(controller.currentError.value?.scope, AppErrorScope.pipeline);
    expect(controller.currentError.value?.title, '网络异常');
    expect(controller.errorHistory.first.message, '请检查网络连接后重试');
  });
}
```

- [ ] **Step 2: 运行新测试，确认当前缺少实现**

Run: `timeout 60s flutter test test/shared/errors/app_error_controller_test.dart`
Expected: FAIL，提示 `app/shared/errors/*` 文件或类型不存在

- [ ] **Step 3: 写最小错误模型与控制器**

```dart
enum AppErrorScope { auth, settings, pipeline, startup, runtime }

enum AppErrorLevel { info, warning, error }

class AppErrorEvent {
  const AppErrorEvent({
    required this.scope,
    required this.level,
    required this.title,
    required this.message,
    DateTime? timestamp,
    this.actionLabel,
    this.actionKey,
  }) : timestamp = timestamp ?? DateTime.now();

  final AppErrorScope scope;
  final AppErrorLevel level;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? actionLabel;
  final String? actionKey;
}
```

```dart
class AppErrorController extends GetxController {
  final currentError = Rxn<AppErrorEvent>();
  final errorHistory = <AppErrorEvent>[].obs;

  void reportEvent(AppErrorEvent event) {
    currentError.value = event;
    errorHistory.insert(0, event);
  }

  // 临时桥接，只用于迁移期编译通过，最终在 Task 5 删除。
  void report({
    required String title,
    required String message,
    AppErrorScope scope = AppErrorScope.runtime,
    AppErrorLevel level = AppErrorLevel.error,
  }) {
    reportEvent(
      AppErrorEvent(
        scope: scope,
        level: level,
        title: title,
        message: message,
      ),
    );
  }

  void clear() {
    currentError.value = null;
    errorHistory.clear();
  }
}
```

- [ ] **Step 4: 让 `PipelineErrorMapper` 直接输出结构化事件**

```dart
class PipelineErrorMapper {
  const PipelineErrorMapper();

  AppErrorEvent mapTdlibFailure(TdlibFailure error) {
    if (classifyTdlibError(error) == TdErrorKind.network) {
      return const AppErrorEvent(
        scope: AppErrorScope.pipeline,
        level: AppErrorLevel.error,
        title: '网络异常',
        message: '请检查网络连接后重试',
      );
    }
    ...
  }
}
```

- [ ] **Step 5: 新增连接状态 port 并让 pipeline 改依赖它**

```dart
abstract class ConnectionStateGateway {
  Stream<TdConnectionState> get connectionStates;
}
```

```dart
class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required ConnectionStateGateway connectionStateGateway,
    ...
  }) : _connectionStateGateway = connectionStateGateway;

  final ConnectionStateGateway _connectionStateGateway;
}
```

- [ ] **Step 6: 跑聚焦验证**

Run: `timeout 60s flutter test test/shared/errors/app_error_controller_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_error_mapper_test.dart`
Expected: PASS

Run: `timeout 60s dart analyze lib/app/shared/errors lib/app/features/pipeline`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add \
  lib/app/shared/errors/app_error_event.dart \
  lib/app/shared/errors/app_error_controller.dart \
  lib/app/features/pipeline/ports/connection_state_gateway.dart \
  lib/app/features/pipeline/application/pipeline_error_mapper.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/shared/presentation/widgets/app_error_panel.dart \
  test/shared/errors/app_error_controller_test.dart \
  test/features/pipeline/application/pipeline_error_mapper_test.dart \
  test/widgets/app_error_panel_test.dart
git commit -m "refactor(core): introduce structured app error events"
```

### Task 2: 迁移 capability ports 并让 DI 按能力装配

**Files:**
- Create: `lib/app/features/auth/ports/auth_gateway.dart`
- Create: `lib/app/features/settings/ports/session_query_gateway.dart`
- Create: `lib/app/features/pipeline/ports/classify_gateway.dart`
- Create: `lib/app/features/pipeline/ports/media_gateway.dart`
- Create: `lib/app/features/pipeline/ports/message_read_gateway.dart`
- Create: `lib/app/features/pipeline/ports/recovery_gateway.dart`
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/core/di/app_bindings.dart`
- Modify: `lib/app/core/di/auth_module.dart`
- Modify: `lib/app/core/di/settings_module.dart`
- Modify: `lib/app/core/di/pipeline_module.dart`
- Modify: `lib/app/features/auth/application/auth_coordinator.dart`
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `test/pages/auth_page_test.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 在 auth 页面测试里先改用最小 port fake，制造失败**

```dart
class _FakeAuthGateway implements AuthGateway, SessionQueryGateway, ConnectionStateGateway {
  ...
}
```

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: FAIL，提示新 ports 路径不存在或 DI / fake 类型不匹配

- [ ] **Step 2: 复制现有接口到最终 ports 路径**

```dart
abstract class AuthGateway {
  Stream<TdAuthState> get authStates;
  Future<void> start();
  Future<void> restart();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);
}
```

```dart
abstract class SessionQueryGateway {
  Future<List<SelectableChat>> listSelectableChats();
}
```

```dart
abstract class MessageReadGateway {
  Future<int> countRemainingMessages({required int? sourceChatId});
  Future<List<PipelineMessage>> fetchMessagePage({...});
  Future<PipelineMessage?> fetchNextMessage({...});
  Future<PipelineMessage> refreshMessage({...});
}
```

- [ ] **Step 3: 让 `TelegramService` 直接实现这些 ports，不再实现 `TelegramGateway`**

```dart
class TelegramService
    implements
        AuthGateway,
        SessionQueryGateway,
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway,
        RecoverableClassifyGateway {
  @override
  Stream<TdConnectionState> get connectionStates => _adapter.connectionStates;
}
```

- [ ] **Step 4: 修改 DI，按能力接口分别注册**

```dart
final telegram = TelegramService(
  adapter: adapter,
  journalRepository: journalRepo,
);

Get.put<AuthGateway>(telegram, permanent: true);
Get.put<SessionQueryGateway>(telegram, permanent: true);
Get.put<ConnectionStateGateway>(telegram, permanent: true);
Get.put<MessageReadGateway>(telegram, permanent: true);
Get.put<MediaGateway>(telegram, permanent: true);
Get.put<ClassifyGateway>(telegram, permanent: true);
Get.put<RecoveryGateway>(telegram, permanent: true);
```

```dart
PipelineCoordinator(
  connectionStateGateway: Get.find<ConnectionStateGateway>(),
  messageGateway: Get.find<MessageReadGateway>(),
  mediaGateway: Get.find<MediaGateway>(),
  classifyGateway: Get.find<ClassifyGateway>(),
  recoveryGateway: Get.find<RecoveryGateway>(),
  ...
)
```

- [ ] **Step 5: 跑 capability 装配回归**

Run: `timeout 60s dart analyze lib/app/core/di lib/app/services lib/app/features`
Expected: PASS

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add \
  lib/app/features/auth/ports/auth_gateway.dart \
  lib/app/features/settings/ports/session_query_gateway.dart \
  lib/app/features/pipeline/ports \
  lib/app/services/telegram_service.dart \
  lib/app/core/di/app_bindings.dart \
  lib/app/core/di/auth_module.dart \
  lib/app/core/di/settings_module.dart \
  lib/app/core/di/pipeline_module.dart \
  lib/app/features/auth/application/auth_coordinator.dart \
  lib/app/features/settings/application/settings_coordinator.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  test/pages/auth_page_test.dart \
  test/integration/auth_pipeline_flow_test.dart
git commit -m "refactor(core): register telegram capabilities by port"
```

### Task 3: 拆薄 SettingsCoordinator

**Files:**
- Create: `lib/app/features/settings/application/settings_draft_coordinator.dart`
- Create: `lib/app/features/settings/application/settings_persistence_service.dart`
- Create: `lib/app/features/settings/application/settings_chat_loader.dart`
- Create: `lib/app/features/settings/application/settings_restart_policy.dart`
- Create: `test/features/settings/application/settings_draft_coordinator_test.dart`
- Create: `test/features/settings/application/settings_persistence_service_test.dart`
- Create: `test/features/settings/application/settings_chat_loader_test.dart`
- Create: `test/features/settings/application/settings_restart_policy_test.dart`
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`
- Modify: `test/features/settings/application/settings_coordinator_test.dart`
- Modify: `test/pages/settings_page_test.dart`
- Modify: `test/controllers/settings_controller_test.dart`

- [ ] **Step 1: 先写 restart policy 与 persistence 的失败测试**

```dart
test('restart policy returns true only when proxy changed', () {
  final policy = SettingsRestartPolicy();

  expect(
    policy.shouldRestart(
      previous: AppSettings.defaults(),
      next: AppSettings.defaults().copyWith(
        proxy: const ProxySettings(server: '127.0.0.1', port: 7890),
      ),
    ),
    isTrue,
  );
});
```

```dart
test('persistence service saves next settings and commits draft', () async {
  final repository = _FakeSettingsRepository();
  final draft = SettingsDraftCoordinator(AppSettings.defaults());
  final service = SettingsPersistenceService(repository: repository);

  draft.update(AppSettings.defaults().updateBatchOptions(batchSize: 8, throttleMs: 0));
  await service.saveDraft(draft);

  expect(repository.saved.batchSize, 8);
  expect(draft.isDirty.value, isFalse);
});
```

- [ ] **Step 2: 运行新测试确认缺少协作者实现**

Run: `timeout 60s flutter test test/features/settings/application/settings_restart_policy_test.dart`
Expected: FAIL

Run: `timeout 60s flutter test test/features/settings/application/settings_persistence_service_test.dart`
Expected: FAIL

- [ ] **Step 3: 写最小 settings 协作者实现**

```dart
class SettingsDraftCoordinator {
  SettingsDraftCoordinator(AppSettings initial)
    : saved = initial.obs,
      draft = initial.obs,
      isDirty = false.obs;

  final Rx<AppSettings> saved;
  final Rx<AppSettings> draft;
  final RxBool isDirty;

  void replace(AppSettings next) { ... }
  void update(AppSettings next) { ... }
  void discard() { ... }
  void commit() { ... }
}
```

```dart
class SettingsRestartPolicy {
  bool shouldRestart({
    required AppSettings previous,
    required AppSettings next,
  }) {
    return previous.proxy != next.proxy;
  }
}
```

```dart
class SettingsPersistenceService {
  SettingsPersistenceService({required SettingsRepository repository})
    : _repository = repository;

  final SettingsRepository _repository;

  AppSettings load() => _repository.load();

  Future<void> saveDraft(SettingsDraftCoordinator draft) async {
    await _repository.save(draft.draft.value);
    draft.commit();
  }
}
```

- [ ] **Step 4: 让 `SettingsCoordinator` 降为 façade**

```dart
class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(
    this._repository,
    this._sessions, {
    AuthGateway? auth,
    SettingsDraftCoordinator? draft,
    SettingsPersistenceService? persistence,
    SettingsChatLoader? chatLoader,
    SettingsRestartPolicy? restartPolicy,
    ...
  }) : _auth = auth,
       _draft = draft ?? SettingsDraftCoordinator(AppSettings.defaults()),
       _persistence =
           persistence ?? SettingsPersistenceService(repository: _repository),
       _chatLoader =
           chatLoader ?? SettingsChatLoader(sessionQueryGateway: _sessions),
       _restartPolicy = restartPolicy ?? SettingsRestartPolicy();
```

```dart
Future<void> saveDraft({bool restartOnProxyChange = true}) async {
  final previous = savedSettings.value;
  final next = draftSettings.value;
  await _persistence.saveDraft(_draft);
  if (_restartPolicy.shouldRestart(previous: previous, next: next) &&
      restartOnProxyChange &&
      _auth != null) {
    await _auth.restart();
  }
}
```

- [ ] **Step 5: 跑 settings 聚焦回归**

Run: `timeout 60s flutter test test/features/settings/application`
Expected: PASS

Run: `timeout 60s flutter test test/pages/settings_page_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/controllers/settings_controller_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add \
  lib/app/features/settings/application/settings_*.dart \
  test/features/settings/application \
  test/pages/settings_page_test.dart \
  test/controllers/settings_controller_test.dart
git commit -m "refactor(settings): split coordinator into focused collaborators"
```

### Task 4: 拆薄 AuthCoordinator 并抽出导航 port

**Files:**
- Create: `lib/app/features/auth/application/auth_error_mapper.dart`
- Create: `lib/app/features/auth/application/auth_lifecycle_coordinator.dart`
- Create: `lib/app/features/auth/ports/auth_navigation_port.dart`
- Create: `lib/app/core/routing/getx_auth_navigation_adapter.dart`
- Create: `test/features/auth/application/auth_error_mapper_test.dart`
- Create: `test/features/auth/application/auth_lifecycle_coordinator_test.dart`
- Modify: `lib/app/features/auth/application/auth_coordinator.dart`
- Modify: `lib/app/core/di/auth_module.dart`
- Modify: `test/pages/auth_page_test.dart`
- Modify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 先写 auth mapper 与 lifecycle 的失败测试**

```dart
test('auth error mapper maps flood wait to auth-scoped error event', () {
  final mapper = AuthErrorMapper();

  final event = mapper.mapTdlibFailure(
    TdlibFailure(code: 429, message: 'Too Many Requests: retry after 9'),
    title: '启动失败',
  );

  expect(event.scope, AppErrorScope.auth);
  expect(event.title, '启动失败');
  expect(event.message, contains('9'));
});
```

```dart
test('lifecycle requests navigation when auth becomes ready', () async {
  final nav = _RecordingAuthNavigationPort();
  final lifecycle = AuthLifecycleCoordinator(
    gateway: _FakeAuthGateway(),
    navigation: nav,
    errors: AppErrorController(),
    mapper: AuthErrorMapper(),
    settings: _FakeSettingsCoordinator(),
  );

  lifecycle.handleAuthState(
    const TdAuthState(
      kind: TdAuthStateKind.ready,
      rawType: 'authorizationStateReady',
    ),
  );

  expect(nav.goToPipelineCalls, 1);
});
```

- [ ] **Step 2: 运行新测试确认实现缺失**

Run: `timeout 60s flutter test test/features/auth/application/auth_error_mapper_test.dart`
Expected: FAIL

Run: `timeout 60s flutter test test/features/auth/application/auth_lifecycle_coordinator_test.dart`
Expected: FAIL

- [ ] **Step 3: 写最小 auth 协作者**

```dart
abstract class AuthNavigationPort {
  void goToPipeline();
}
```

```dart
class GetxAuthNavigationAdapter implements AuthNavigationPort {
  @override
  void goToPipeline() {
    Get.offNamed(AppRoutes.pipeline);
  }
}
```

```dart
class AuthLifecycleCoordinator {
  AuthLifecycleCoordinator({
    required AuthGateway gateway,
    required AppErrorController errors,
    required AuthErrorMapper mapper,
    required SettingsCoordinator settings,
    required AuthNavigationPort navigation,
  }) : _gateway = gateway,
       _errors = errors,
       _mapper = mapper,
       _settings = settings,
       _navigation = navigation;

  void handleAuthState(TdAuthState state) {
    if (state.kind == TdAuthStateKind.ready) {
      _navigation.goToPipeline();
    }
  }
}
```

- [ ] **Step 4: 让 `AuthCoordinator` 成为 façade**

```dart
class AuthCoordinator extends GetxController {
  AuthCoordinator(
    this._service,
    this._errors,
    this._settings, {
    AuthLifecycleCoordinator? lifecycle,
    AuthErrorMapper? mapper,
  }) : _mapper = mapper ?? const AuthErrorMapper(),
       _lifecycle =
           lifecycle ??
           AuthLifecycleCoordinator(
             gateway: _service,
             errors: _errors,
             mapper: _mapper,
             settings: _settings,
             navigation: GetxAuthNavigationAdapter(),
           );
```

- [ ] **Step 5: 跑 auth 聚焦回归**

Run: `timeout 60s flutter test test/features/auth/application`
Expected: PASS

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add \
  lib/app/features/auth/application/auth_*.dart \
  lib/app/features/auth/ports/auth_navigation_port.dart \
  lib/app/core/routing/getx_auth_navigation_adapter.dart \
  lib/app/core/di/auth_module.dart \
  test/features/auth/application \
  test/pages/auth_page_test.dart \
  test/integration/auth_pipeline_flow_test.dart
git commit -m "refactor(auth): split lifecycle mapper and navigation"
```

### Task 5: 删除过渡接口与迁移期桥接

**Files:**
- Delete: `lib/app/services/telegram_gateway.dart`
- Delete: `lib/app/controllers/app_error_controller.dart`
- Delete: `lib/app/features/auth/application/auth_gateway.dart`
- Delete: `lib/app/features/settings/application/session_query_gateway.dart`
- Delete: `lib/app/features/pipeline/application/classify_gateway.dart`
- Delete: `lib/app/features/pipeline/application/media_gateway.dart`
- Delete: `lib/app/features/pipeline/application/message_read_gateway.dart`
- Delete: `lib/app/features/pipeline/application/recovery_gateway.dart`
- Modify: 全仓相关 imports 与 fake types
- Modify: `docs/ARCHITECTURE.md`

- [ ] **Step 1: 先在全仓搜索残留引用**

Run: `rg -n "TelegramGateway|controllers/app_error_controller|features/.*/application/(auth_gateway|session_query_gateway|classify_gateway|media_gateway|message_read_gateway|recovery_gateway)" lib test docs`
Expected: 输出残留引用清单

- [ ] **Step 2: 更新 fake / harness 到最小能力组合**

```dart
class _IntegrationFakeGateway
    implements
        AuthGateway,
        SessionQueryGateway,
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway {
  ...
}
```

- [ ] **Step 3: 删除 AppErrorController 迁移期桥接接口**

```dart
class AppErrorController extends GetxController {
  final currentError = Rxn<AppErrorEvent>();
  final errorHistory = <AppErrorEvent>[].obs;

  void reportEvent(AppErrorEvent event) { ... }
  void clear() { ... }
}
```

所有调用点改成：

```dart
_errors.reportEvent(
  _mapper.mapTdlibFailure(error, title: '启动失败'),
);
```

- [ ] **Step 4: 删除旧接口文件并修正文档**

```bash
git rm \
  lib/app/services/telegram_gateway.dart \
  lib/app/controllers/app_error_controller.dart \
  lib/app/features/auth/application/auth_gateway.dart \
  lib/app/features/settings/application/session_query_gateway.dart \
  lib/app/features/pipeline/application/classify_gateway.dart \
  lib/app/features/pipeline/application/media_gateway.dart \
  lib/app/features/pipeline/application/message_read_gateway.dart \
  lib/app/features/pipeline/application/recovery_gateway.dart
```

- [ ] **Step 5: 跑删除旧层后的核心回归**

Run: `timeout 60s dart analyze`
Expected: PASS

Run: `timeout 60s flutter test test/controllers`
Expected: PASS

Run: `timeout 60s flutter test test/pages`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add docs/ARCHITECTURE.md lib test
git commit -m "refactor(core): remove transition gateways and old error controller"
```

### Task 6: 全量回归与结构验收

**Files:**
- Modify: `docs/ARCHITECTURE.md`
- Verify: 全仓

- [ ] **Step 1: 跑静态检查**

Run: `timeout 60s dart analyze`
Expected: PASS，输出 `No issues found!`

- [ ] **Step 2: 跑 feature application 回归**

Run: `timeout 60s flutter test test/features/auth/application`
Expected: PASS

Run: `timeout 60s flutter test test/features/settings/application`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application`
Expected: PASS

- [ ] **Step 3: 跑页面与控制器回归**

Run: `timeout 60s flutter test test/controllers`
Expected: PASS

Run: `timeout 60s flutter test test/pages`
Expected: PASS

- [ ] **Step 4: 跑集成与全仓回归**

Run: `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

Run: `timeout 60s flutter test`
Expected: PASS，最后输出 `All tests passed!`

- [ ] **Step 5: 结构验收**

Run: `rg -n "TelegramGateway" lib test docs`
Expected: 无业务代码残留引用

Run: `rg -n "report\\(" lib test | rg "AppErrorController"`
Expected: 无旧字符串协议调用

Run: `find lib/app/features -maxdepth 2 -type d | sort`
Expected: auth / settings / pipeline 目录结构与设计一致

- [ ] **Step 6: 提交并推送**

```bash
git add docs/ARCHITECTURE.md
git commit -m "refactor: finalize architecture closure"
git push
```

## Self-Review

- Spec coverage:
  - capability ports 收口：Task 2、Task 5 覆盖
  - settings 拆薄：Task 3 覆盖
  - auth 拆薄与导航 port：Task 4 覆盖
  - 结构化错误系统：Task 1、Task 5 覆盖
  - DI / 路由 / 页面接线：Task 2、Task 4、Task 5 覆盖
  - 文档与全量验收：Task 6 覆盖
- Placeholder scan:
  - 无 `TODO`、`TBD`、`implement later`、`后续补上`、`适当处理`
- Type consistency:
  - 统一使用 `AppErrorEvent`、`AppErrorController.reportEvent(...)`
  - 统一使用 `AuthNavigationPort`、`ConnectionStateGateway`
  - capability ports 最终路径统一落在 `features/*/ports`
