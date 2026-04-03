# Steady-State Architecture Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在保持现有产品行为、GetX 技术栈和 TDLib 业务语义基本稳定的前提下，完成一次覆盖 pipeline、settings、gateway、DI 与目录结构的稳态大重构，并建立新的测试回归边界。

**Architecture:** 以 `core / features / shared` 为目标结构，先建立 capability interfaces 与 coordinator 骨架，再优先拆解 `PipelineController`，随后将 `TelegramService` 收口为多接口 facade，并把 `SettingsController` 拆成协调器与子域服务。最终再进行目录迁移、DI 模块化与测试收口，避免“搬目录”和“改行为”同时失控。

**Tech Stack:** Flutter、Dart 3.11、GetX、TDLib、`flutter_test`

---

## File Map

**Create**
- `lib/app/core/di/app_bindings.dart` — 总装配入口
- `lib/app/core/di/auth_module.dart` — auth 模块装配
- `lib/app/core/di/pipeline_module.dart` — pipeline 模块装配
- `lib/app/core/di/settings_module.dart` — settings 模块装配
- `lib/app/core/routing/app_routes.dart` — 路由常量与页面注册
- `lib/app/features/auth/application/auth_gateway.dart` — auth 能力接口
- `lib/app/features/auth/application/auth_coordinator.dart` — auth 协调器
- `lib/app/features/pipeline/application/pipeline_runtime_state.dart` — pipeline 运行态
- `lib/app/features/pipeline/application/pipeline_navigation_service.dart` — 导航与缓存协作者
- `lib/app/features/pipeline/application/pipeline_action_service.dart` — 分类、跳过、撤销、重试协作者
- `lib/app/features/pipeline/application/pipeline_recovery_service.dart` — classify 恢复协作者
- `lib/app/features/pipeline/application/pipeline_media_refresh_service.dart` — 媒体刷新协作者
- `lib/app/features/pipeline/application/remaining_count_service.dart` — 剩余统计协作者
- `lib/app/features/pipeline/application/pipeline_settings_reader.dart` — pipeline 只读配置契约
- `lib/app/features/pipeline/application/pipeline_coordinator.dart` — pipeline 协调器
- `lib/app/features/pipeline/application/message_read_gateway.dart` — 消息读取能力接口
- `lib/app/features/pipeline/application/media_gateway.dart` — 媒体能力接口
- `lib/app/features/pipeline/application/classify_gateway.dart` — 分类能力接口
- `lib/app/features/pipeline/application/recovery_gateway.dart` — 恢复能力接口
- `lib/app/features/settings/application/settings_draft_session.dart` — 草稿会话
- `lib/app/features/settings/application/category_settings_service.dart` — 分类配置服务
- `lib/app/features/settings/application/shortcut_settings_service.dart` — 快捷键配置服务
- `lib/app/features/settings/application/connection_settings_service.dart` — 连接配置服务
- `lib/app/features/settings/application/chat_selection_service.dart` — chat 加载服务
- `lib/app/features/settings/application/settings_coordinator.dart` — settings 协调器
- `lib/app/features/settings/application/session_query_gateway.dart` — chat 查询能力接口
- `lib/app/features/settings/domain/workflow_settings.dart` — 工作流设置值对象
- `lib/app/features/settings/domain/connection_settings.dart` — 连接设置值对象
- `lib/app/features/settings/domain/shortcut_settings.dart` — 快捷键设置值对象
- `test/features/pipeline/application/pipeline_navigation_service_test.dart`
- `test/features/pipeline/application/pipeline_action_service_test.dart`
- `test/features/pipeline/application/pipeline_recovery_service_test.dart`
- `test/features/pipeline/application/pipeline_media_refresh_service_test.dart`
- `test/features/pipeline/application/remaining_count_service_test.dart`
- `test/features/settings/application/settings_draft_session_test.dart`
- `test/features/settings/application/settings_coordinator_test.dart`

**Modify**
- `lib/app/app.dart` — 改为使用 `app_routes.dart`
- `lib/app/bindings.dart` — 过渡到 `core/di/app_bindings.dart`
- `lib/app/controllers/auth_controller.dart` — 迁移到 auth coordinator 或兼容壳
- `lib/app/controllers/pipeline_controller.dart` — 迁移到 pipeline coordinator 或兼容壳
- `lib/app/controllers/settings_controller.dart` — 迁移到 settings coordinator 或兼容壳
- `lib/app/controllers/pipeline_settings_provider.dart` — 收敛到 `pipeline_settings_reader.dart`
- `lib/app/services/telegram_gateway.dart` — 拆分旧大接口或降级为兼容层
- `lib/app/services/telegram_service.dart` — 改为实现多个 capability interfaces 的 facade
- `lib/app/models/app_settings.dart` — 内部拆为子值对象聚合
- `lib/app/pages/auth_page.dart`
- `lib/app/pages/pipeline_page.dart`
- `lib/app/pages/pipeline_mobile_view.dart`
- `lib/app/pages/pipeline_desktop_view.dart`
- `lib/app/pages/settings_page.dart`
- `docs/ARCHITECTURE.md`
- `test/controllers/pipeline_controller_test.dart`
- `test/controllers/settings_controller_test.dart`
- `test/pages/auth_page_test.dart`
- `test/pages/pipeline_layout_test.dart`
- `test/pages/pipeline_mobile_view_test.dart`
- `test/pages/settings_page_test.dart`
- `test/integration/auth_pipeline_flow_test.dart`

### Task 1: 建立 capability interface 与 coordinator 骨架

**Files:**
- Create: `lib/app/features/auth/application/auth_gateway.dart`
- Create: `lib/app/features/pipeline/application/message_read_gateway.dart`
- Create: `lib/app/features/pipeline/application/media_gateway.dart`
- Create: `lib/app/features/pipeline/application/classify_gateway.dart`
- Create: `lib/app/features/pipeline/application/recovery_gateway.dart`
- Create: `lib/app/features/settings/application/session_query_gateway.dart`
- Create: `lib/app/features/pipeline/application/pipeline_settings_reader.dart`
- Create: `lib/app/features/auth/application/auth_coordinator.dart`
- Create: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Create: `lib/app/features/settings/application/settings_coordinator.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 先在服务测试里加 capability view 的失败测试**

```dart
test('TelegramService can be viewed as split capability interfaces', () {
  final service = TelegramService(adapter: _FakeTdlibAdapter());

  final auth = service as AuthGateway;
  final messages = service as MessageReadGateway;
  final media = service as MediaGateway;
  final classify = service as ClassifyGateway;
  final recovery = service as RecoveryGateway;
  final sessions = service as SessionQueryGateway;

  expect(auth, isNotNull);
  expect(messages, isNotNull);
  expect(media, isNotNull);
  expect(classify, isNotNull);
  expect(recovery, isNotNull);
  expect(sessions, isNotNull);
});
```

- [ ] **Step 2: 运行单测确认 capability interfaces 还不存在**

Run: `timeout 60s flutter test test/services/telegram_service_test.dart --plain-name "TelegramService can be viewed as split capability interfaces"`
Expected: FAIL，提示 `AuthGateway`、`MessageReadGateway`、`SessionQueryGateway` 等类型未定义

- [ ] **Step 3: 创建 capability interfaces 与 coordinator 最小骨架**

```dart
abstract class AuthGateway {
  Stream<TdAuthState> get authStates;
  Future<void> start();
  Future<void> restart();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);
}

abstract class MessageReadGateway {
  Future<int> countRemainingMessages({required int? sourceChatId});
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  });
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  });
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  });
}

abstract class MediaGateway {
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  });
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  });
}

abstract class ClassifyGateway {
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  });
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  });
}

abstract class RecoveryGateway {
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}

abstract class SessionQueryGateway {
  Future<List<SelectableChat>> listSelectableChats();
}

abstract class PipelineSettingsReader {
  Rx<AppSettings> get settingsStream;
  AppSettings get currentSettings;
  CategoryConfig getCategory(String key);
}

class AuthCoordinator extends GetxController {
  AuthCoordinator(this._auth, this._errors, this._settings);

  final AuthGateway _auth;
  final AppErrorController _errors;
  final SettingsCoordinator _settings;
}

class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required MessageReadGateway messages,
    required MediaGateway media,
    required ClassifyGateway classify,
    required RecoveryGateway recovery,
    required PipelineSettingsReader settings,
    required OperationJournalRepository journalRepository,
    required AppErrorController errorController,
  });
}

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(this._repository, this._sessions);

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
}
```

- [ ] **Step 4: 让 `TelegramService` 实现新 interfaces，并保留旧接口兼容**

```dart
class TelegramService
    implements
        AuthGateway,
        SessionQueryGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway,
        TelegramGateway,
        RecoverableClassifyGateway {
  // 现有实现暂时不动，先把类型边界建立起来
}
```

Run: `timeout 60s flutter test test/services/telegram_service_test.dart --plain-name "TelegramService can be viewed as split capability interfaces"`
Expected: PASS

- [ ] **Step 5: 提交骨架与 capability interfaces**

```bash
git add \
  lib/app/features/auth/application/auth_gateway.dart \
  lib/app/features/auth/application/auth_coordinator.dart \
  lib/app/features/pipeline/application/message_read_gateway.dart \
  lib/app/features/pipeline/application/media_gateway.dart \
  lib/app/features/pipeline/application/classify_gateway.dart \
  lib/app/features/pipeline/application/recovery_gateway.dart \
  lib/app/features/pipeline/application/pipeline_settings_reader.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/features/settings/application/session_query_gateway.dart \
  lib/app/features/settings/application/settings_coordinator.dart \
  lib/app/services/telegram_gateway.dart \
  lib/app/services/telegram_service.dart \
  test/services/telegram_service_test.dart
git commit -m "refactor: add capability interfaces and coordinator skeletons"
```

### Task 2: 抽取 `PipelineRuntimeState` 与 `PipelineNavigationService`

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_runtime_state.dart`
- Create: `lib/app/features/pipeline/application/pipeline_navigation_service.dart`
- Create: `test/features/pipeline/application/pipeline_navigation_service_test.dart`
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`

- [ ] **Step 1: 为 navigation service 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test('showNext moves current index and exposes next cached message', () async {
    final state = PipelineRuntimeState();
    final service = PipelineNavigationService(state: state);
    final first = fakePipelineMessage(id: 101);
    final second = fakePipelineMessage(id: 102);

    service.replaceMessages(<PipelineMessage>[first, second]);

    expect(state.currentMessage.value?.id, 101);
    await service.showNext();
    expect(state.currentMessage.value?.id, 102);
    expect(state.canShowPrevious.value, isTrue);
  });
}
```

- [ ] **Step 2: 运行单测确认 service 尚未实现**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_navigation_service_test.dart`
Expected: FAIL，提示 `PipelineRuntimeState` 或 `PipelineNavigationService` 未定义

- [ ] **Step 3: 实现运行态对象与最小导航服务**

```dart
class PipelineRuntimeState {
  final currentMessage = Rxn<PipelineMessage>();
  final canShowPrevious = false.obs;
  final canShowNext = false.obs;
  final loading = false.obs;
  final processing = false.obs;
  final videoPreparing = false.obs;
  final isOnline = false.obs;
  final remainingCount = RxnInt();
  final remainingCountLoading = false.obs;

  final List<PipelineMessage> cache = <PipelineMessage>[];
  int currentIndex = -1;
}

class PipelineNavigationService {
  PipelineNavigationService({required PipelineRuntimeState state})
    : _state = state;

  final PipelineRuntimeState _state;

  void replaceMessages(List<PipelineMessage> messages) {
    _state.cache
      ..clear()
      ..addAll(messages);
    _state.currentIndex = messages.isEmpty ? -1 : 0;
    _syncCurrentMessage();
  }

  Future<void> showNext() async {
    if (_state.currentIndex + 1 >= _state.cache.length) {
      return;
    }
    _state.currentIndex++;
    _syncCurrentMessage();
  }

  Future<void> showPrevious() async {
    if (_state.currentIndex <= 0) {
      return;
    }
    _state.currentIndex--;
    _syncCurrentMessage();
  }

  void _syncCurrentMessage() {
    _state.currentMessage.value = _state.currentIndex < 0
        ? null
        : _state.cache[_state.currentIndex];
    _state.canShowPrevious.value = _state.currentIndex > 0;
    _state.canShowNext.value = _state.currentIndex >= 0 &&
        _state.currentIndex + 1 < _state.cache.length;
  }
}
```

- [ ] **Step 4: 把 `PipelineController` 的缓存与导航状态迁移到 service**

```dart
class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required this.navigation,
    required this.runtimeState,
    // 其他依赖后续任务补齐
  });

  final PipelineNavigationService navigation;
  final PipelineRuntimeState runtimeState;

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
}
```

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_navigation_service_test.dart`
Expected: PASS

- [ ] **Step 5: 提交 pipeline 运行态与导航服务**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_runtime_state.dart \
  lib/app/features/pipeline/application/pipeline_navigation_service.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/controllers/pipeline_controller.dart \
  test/features/pipeline/application/pipeline_navigation_service_test.dart
git commit -m "refactor(pipeline): extract runtime state and navigation service"
```

### Task 3: 抽取 `PipelineActionService`、`PipelineRecoveryService`、`RemainingCountService`

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_action_service.dart`
- Create: `lib/app/features/pipeline/application/pipeline_recovery_service.dart`
- Create: `lib/app/features/pipeline/application/pipeline_media_refresh_service.dart`
- Create: `lib/app/features/pipeline/application/remaining_count_service.dart`
- Create: `test/features/pipeline/application/pipeline_action_service_test.dart`
- Create: `test/features/pipeline/application/pipeline_recovery_service_test.dart`
- Create: `test/features/pipeline/application/pipeline_media_refresh_service_test.dart`
- Create: `test/features/pipeline/application/remaining_count_service_test.dart`
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`

- [ ] **Step 1: 先写 action/recovery/count 三组失败测试**

```dart
test('classify success appends log and removes current message', () async {
  final harness = _PipelineActionHarness.success();
  final service = harness.build();

  final ok = await service.classifyCurrent('work');

  expect(ok, isTrue);
  expect(harness.appendedLogs.single.status, ClassifyOperationStatus.success);
  expect(harness.removedCurrentMessage, isTrue);
});

test('recoverPendingTransactions reports recovered count once', () async {
  final harness = _PipelineRecoveryHarness.success();
  final service = harness.build();

  await service.recoverPendingTransactionsIfNeeded();
  await service.recoverPendingTransactionsIfNeeded();

  expect(harness.recoverCalls, 1);
});

test('prepareCurrentMedia refreshes current message with prepared payload', () async {
  final harness = _PipelineMediaRefreshHarness.videoReady();
  final service = harness.build();

  final refreshed = await service.prepareCurrentMedia(
    sourceChatId: 777,
    messageId: 21,
  );

  expect(refreshed.preview.videoPath, '/tmp/video.mp4');
  expect(harness.prepareCalls, 1);
});

test('remaining count ignores stale response', () async {
  final service = RemainingCountService();

  final first = service.beginRequest();
  final second = service.beginRequest();

  expect(service.shouldApply(first), isFalse);
  expect(service.shouldApply(second), isTrue);
});
```

- [ ] **Step 2: 运行新单测确认对象尚未实现**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_action_service_test.dart`
Expected: FAIL

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_recovery_service_test.dart`
Expected: FAIL

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_media_refresh_service_test.dart`
Expected: FAIL

Run: `timeout 60s flutter test test/features/pipeline/application/remaining_count_service_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现最小 action/recovery/count 协作者**

```dart
class PipelineActionService {
  PipelineActionService({
    required PipelineRuntimeState state,
    required PipelineNavigationService navigation,
    required ClassifyGateway classifyGateway,
    required PipelineSettingsReader settings,
    required OperationJournalRepository journalRepository,
  }) : _state = state,
       _navigation = navigation,
       _classifyGateway = classifyGateway,
       _settings = settings,
       _journalRepository = journalRepository;

  Future<bool> classifyCurrent(String key) async {
    final message = _state.currentMessage.value;
    if (message == null || _state.processing.value) {
      return false;
    }
    final target = _settings.getCategory(key);
    _state.processing.value = true;
    try {
      await _classifyGateway.classifyMessage(
        sourceChatId: message.sourceChatId,
        messageIds: message.messageIds,
        targetChatId: target.targetChatId,
        asCopy: _settings.currentSettings.forwardAsCopy,
      );
      _journalRepository.appendLog(
        ClassifyOperationLog(
          id: 'ok-${message.id}',
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.success,
        ),
      );
      _navigation.removeCurrent();
      return true;
    } finally {
      _state.processing.value = false;
    }
  }
}

class PipelineRecoveryService {
  PipelineRecoveryService({
    required RecoveryGateway recoveryGateway,
    required AppErrorController errors,
  }) : _recoveryGateway = recoveryGateway,
       _errors = errors;

  final RecoveryGateway _recoveryGateway;
  final AppErrorController _errors;
  bool _completed = false;
  bool _running = false;

  Future<void> recoverPendingTransactionsIfNeeded() async {
    if (_completed || _running) {
      return;
    }
    _running = true;
    try {
      final summary = await _recoveryGateway.recoverPendingClassifyOperations();
      _completed = true;
      if (summary.failedCount > 0) {
        _errors.report(title: '恢复失败', message: '存在未恢复事务');
      }
    } finally {
      _running = false;
    }
  }
}

class PipelineMediaRefreshService {
  PipelineMediaRefreshService({
    required MediaGateway mediaGateway,
    required MessageReadGateway messageGateway,
  }) : _mediaGateway = mediaGateway,
       _messageGateway = messageGateway;

  final MediaGateway _mediaGateway;
  final MessageReadGateway _messageGateway;

  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    final prepared = await _mediaGateway.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
    return _messageGateway.refreshMessage(
      sourceChatId: prepared.sourceChatId,
      messageId: prepared.id,
    );
  }
}

class RemainingCountService {
  int _requestId = 0;

  int beginRequest() {
    _requestId++;
    return _requestId;
  }

  bool shouldApply(int requestId) => requestId == _requestId;
}
```

- [ ] **Step 4: 在 `PipelineCoordinator` 中组合这些协作者，并回归旧 controller 测试**

```dart
class PipelineCoordinator extends GetxController {
  PipelineCoordinator({
    required this.runtimeState,
    required this.navigation,
    required this.actions,
    required this.recovery,
    required this.mediaRefresh,
    required this.remainingCount,
  });

  final PipelineRuntimeState runtimeState;
  final PipelineNavigationService navigation;
  final PipelineActionService actions;
  final PipelineRecoveryService recovery;
  final PipelineMediaRefreshService mediaRefresh;
  final RemainingCountService remainingCount;

  Future<bool> classify(String key) => actions.classifyCurrent(key);
  Future<void> showNextMessage() => navigation.showNext();
  Future<void> showPreviousMessage() => navigation.showPrevious();
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) => mediaRefresh.prepareCurrentMedia(
    sourceChatId: sourceChatId,
    messageId: messageId,
  );
}
```

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_action_service_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_recovery_service_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_media_refresh_service_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application/remaining_count_service_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/controllers/pipeline_controller_test.dart`
Expected: PASS，或仅需微调测试构造以适配协调器包装

- [ ] **Step 5: 提交 pipeline 行为协作者**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_action_service.dart \
  lib/app/features/pipeline/application/pipeline_recovery_service.dart \
  lib/app/features/pipeline/application/pipeline_media_refresh_service.dart \
  lib/app/features/pipeline/application/remaining_count_service.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/controllers/pipeline_controller.dart \
  test/features/pipeline/application/pipeline_action_service_test.dart \
  test/features/pipeline/application/pipeline_recovery_service_test.dart \
  test/features/pipeline/application/pipeline_media_refresh_service_test.dart \
  test/features/pipeline/application/remaining_count_service_test.dart \
  test/controllers/pipeline_controller_test.dart
git commit -m "refactor(pipeline): extract action recovery and count services"
```

### Task 4: 让 `TelegramService` 成为 capability-based facade

**Files:**
- Modify: `lib/app/services/telegram_service.dart`
- Modify: `lib/app/services/telegram_gateway.dart`
- Modify: `lib/app/features/auth/application/auth_gateway.dart`
- Modify: `lib/app/features/pipeline/application/message_read_gateway.dart`
- Modify: `lib/app/features/pipeline/application/media_gateway.dart`
- Modify: `lib/app/features/pipeline/application/classify_gateway.dart`
- Modify: `lib/app/features/pipeline/application/recovery_gateway.dart`
- Modify: `lib/app/features/settings/application/session_query_gateway.dart`
- Test: `test/services/telegram_service_test.dart`

- [ ] **Step 1: 在 `telegram_service_test.dart` 中加一条 facade 回归测试**

```dart
test('split capability interfaces keep existing classify behavior', () async {
  final service = TelegramService(
    adapter: _FakeTdlibAdapter(
      wireResponses: <String, List<TdWireEnvelope>>{
        'forwardMessages': <TdWireEnvelope>[
          TdWireEnvelope.fromJson(<String, dynamic>{
            '@type': 'messages',
            'messages': [_textMessageJson(88, 'copied')],
          }),
        ],
      },
    ),
  );
  final classify = service as ClassifyGateway;

  final receipt = await classify.classifyMessage(
    sourceChatId: 777,
    messageIds: const [10],
    targetChatId: 999,
    asCopy: false,
  );

  expect(receipt.sourceChatId, 777);
  expect(receipt.targetChatId, 999);
  expect(receipt.sourceMessageIds, <int>[10]);
});
```

- [ ] **Step 2: 运行服务测试确认 facade 改造前仍有缺口**

Run: `timeout 60s flutter test test/services/telegram_service_test.dart --plain-name "split capability interfaces keep existing classify behavior"`
Expected: FAIL，提示新的 interface 组合与测试桩构造未完全接通

- [ ] **Step 3: 用小接口替换旧大接口在各模块中的注入依赖**

```dart
class AuthCoordinator extends GetxController {
  AuthCoordinator(
    this._auth,
    this._errors,
    this._settings,
  );

  final AuthGateway _auth;
  final AppErrorController _errors;
  final SettingsCoordinator _settings;
}

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(
    this._repository,
    this._sessions,
  );

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
}
```

- [ ] **Step 4: 让 `TelegramGateway` 降级为兼容组合接口，并跑核心服务回归**

```dart
abstract class TelegramGateway
    implements
        AuthGateway,
        SessionQueryGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway {}
```

Run: `timeout 60s flutter test test/services/telegram_service_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/services/telegram_classify_workflow_test.dart`
Expected: PASS

- [ ] **Step 5: 提交 capability-based facade 改造**

```bash
git add \
  lib/app/services/telegram_service.dart \
  lib/app/services/telegram_gateway.dart \
  lib/app/features/auth/application/auth_gateway.dart \
  lib/app/features/pipeline/application/message_read_gateway.dart \
  lib/app/features/pipeline/application/media_gateway.dart \
  lib/app/features/pipeline/application/classify_gateway.dart \
  lib/app/features/pipeline/application/recovery_gateway.dart \
  lib/app/features/settings/application/session_query_gateway.dart \
  test/services/telegram_service_test.dart
git commit -m "refactor: turn telegram service into capability facade"
```

### Task 5: 拆分 settings 草稿域与 `SettingsCoordinator`

**Files:**
- Create: `lib/app/features/settings/application/settings_draft_session.dart`
- Create: `lib/app/features/settings/application/category_settings_service.dart`
- Create: `lib/app/features/settings/application/shortcut_settings_service.dart`
- Create: `lib/app/features/settings/application/connection_settings_service.dart`
- Create: `lib/app/features/settings/application/chat_selection_service.dart`
- Create: `lib/app/features/settings/domain/workflow_settings.dart`
- Create: `lib/app/features/settings/domain/connection_settings.dart`
- Create: `lib/app/features/settings/domain/shortcut_settings.dart`
- Create: `test/features/settings/application/settings_draft_session_test.dart`
- Create: `test/features/settings/application/settings_coordinator_test.dart`
- Modify: `lib/app/models/app_settings.dart`
- Modify: `lib/app/controllers/settings_controller.dart`
- Modify: `lib/app/features/settings/application/settings_coordinator.dart`

- [ ] **Step 1: 先写 draft session 和 coordinator 失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_session.dart';
import 'package:tgsorter/app/models/app_settings.dart';

void main() {
  test('update marks draft dirty until discard', () {
    final session = SettingsDraftSession(AppSettings.defaults());

    session.update(
      session.draft.value.updateForwardAsCopy(true),
    );

    expect(session.isDirty.value, isTrue);
    session.discard();
    expect(session.isDirty.value, isFalse);
  });
}
```

```dart
test('save persists draft and restarts only when proxy changes', () async {
  final harness = _SettingsCoordinatorHarness();
  final coordinator = harness.build();

  coordinator.updateProxyDraft(
    server: '127.0.0.1',
    port: '7890',
    username: '',
    password: '',
  );
  await coordinator.saveDraft();

  expect(harness.saveCalls, 1);
  expect(harness.restartCalls, 1);
});
```

- [ ] **Step 2: 运行新测试确认 session 与 coordinator 尚未实现**

Run: `timeout 60s flutter test test/features/settings/application/settings_draft_session_test.dart`
Expected: FAIL

Run: `timeout 60s flutter test test/features/settings/application/settings_coordinator_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现子值对象、draft session 与最小 settings services**

```dart
class WorkflowSettings {
  const WorkflowSettings({
    required this.sourceChatId,
    required this.fetchDirection,
    required this.forwardAsCopy,
    required this.batchSize,
    required this.throttleMs,
    required this.previewPrefetchCount,
    required this.categories,
  });

  final int? sourceChatId;
  final MessageFetchDirection fetchDirection;
  final bool forwardAsCopy;
  final int batchSize;
  final int throttleMs;
  final int previewPrefetchCount;
  final List<CategoryConfig> categories;
}

class ConnectionSettings {
  const ConnectionSettings({required this.proxy});
  final ProxySettings proxy;
}

class ShortcutSettings {
  const ShortcutSettings({required this.bindings});
  final Map<ShortcutAction, ShortcutBinding> bindings;
}

class SettingsDraftSession {
  SettingsDraftSession(AppSettings initial)
    : saved = initial.obs,
      draft = initial.obs,
      isDirty = false.obs;

  final Rx<AppSettings> saved;
  final Rx<AppSettings> draft;
  final RxBool isDirty;

  void update(AppSettings next) {
    draft.value = next;
    isDirty.value = draft.value != saved.value;
  }

  void discard() {
    draft.value = saved.value;
    isDirty.value = false;
  }

  void commit() {
    saved.value = draft.value;
    isDirty.value = false;
  }
}

class ConnectionSettingsService {
  AppSettings updateProxy({
    required AppSettings current,
    required String server,
    required String port,
    required String username,
    required String password,
  }) {
    return current.updateProxySettings(
      ProxySettings(
        server: server,
        port: int.tryParse(port.trim()),
        username: username,
        password: password,
      ),
    );
  }
}
```

- [ ] **Step 4: 让 `SettingsCoordinator` 组合这些 services，并回归旧 settings 测试**

```dart
class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(
    this._repository,
    this._sessions, {
    SettingsDraftSession? draftSession,
    CategorySettingsService? categories,
    ShortcutSettingsService? shortcuts,
    ConnectionSettingsService? connection,
    ChatSelectionService? chats,
  }) : _draftSession = draftSession ?? SettingsDraftSession(AppSettings.defaults()),
       _categories = categories ?? CategorySettingsService(),
       _shortcuts = shortcuts ?? ShortcutSettingsService(),
       _connection = connection ?? ConnectionSettingsService(),
       _chats = chats ?? ChatSelectionService(sessionQueryGateway: _sessions);

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
  final SettingsDraftSession _draftSession;
  final CategorySettingsService _categories;
  final ShortcutSettingsService _shortcuts;
  final ConnectionSettingsService _connection;
  final ChatSelectionService _chats;
}
```

Run: `timeout 60s flutter test test/features/settings/application/settings_draft_session_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/settings/application/settings_coordinator_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/controllers/settings_controller_test.dart`
Expected: PASS，或改为适配 `SettingsCoordinator` 后通过

- [ ] **Step 5: 提交 settings 拆分**

```bash
git add \
  lib/app/features/settings/application/settings_draft_session.dart \
  lib/app/features/settings/application/category_settings_service.dart \
  lib/app/features/settings/application/shortcut_settings_service.dart \
  lib/app/features/settings/application/connection_settings_service.dart \
  lib/app/features/settings/application/chat_selection_service.dart \
  lib/app/features/settings/application/settings_coordinator.dart \
  lib/app/features/settings/domain/workflow_settings.dart \
  lib/app/features/settings/domain/connection_settings.dart \
  lib/app/features/settings/domain/shortcut_settings.dart \
  lib/app/models/app_settings.dart \
  lib/app/controllers/settings_controller.dart \
  test/features/settings/application/settings_draft_session_test.dart \
  test/features/settings/application/settings_coordinator_test.dart \
  test/controllers/settings_controller_test.dart
git commit -m "refactor(settings): split draft domain and coordinator"
```

### Task 6: 引入模块化 DI 与路由装配

**Files:**
- Create: `lib/app/core/di/app_bindings.dart`
- Create: `lib/app/core/di/auth_module.dart`
- Create: `lib/app/core/di/pipeline_module.dart`
- Create: `lib/app/core/di/settings_module.dart`
- Create: `lib/app/core/routing/app_routes.dart`
- Modify: `lib/app/bindings.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/app/pages/auth_page.dart`
- Modify: `lib/app/pages/pipeline_page.dart`
- Modify: `lib/app/pages/settings_page.dart`
- Test: `test/pages/auth_page_test.dart`
- Test: `test/pages/pipeline_layout_test.dart`
- Test: `test/pages/pipeline_mobile_view_test.dart`
- Test: `test/pages/settings_page_test.dart`

- [ ] **Step 1: 先写页面装配层的失败测试**

```dart
testWidgets('app routes resolve pages from modular bindings', (tester) async {
  await tester.pumpWidget(const TgSorterApp());
  expect(find.byType(AuthPage), findsOneWidget);
});
```

- [ ] **Step 2: 运行页面测试确认路由装配还未迁移**

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: FAIL，或因构造方式变更需要先引入新路由常量

- [ ] **Step 3: 创建模块化 bindings 与路由常量**

```dart
abstract final class AppRoutes {
  static const auth = '/auth';
  static const pipeline = '/pipeline';
  static const settings = '/settings';
}

Future<void> initDependencies() => registerAppBindings();

Future<void> registerAppBindings() async {
  await registerCoreModule();
  registerSettingsModule();
  registerAuthModule();
  registerPipelineModule();
}
```

```dart
void registerAuthModule() {
  Get.put(
    AuthCoordinator(
      Get.find<AuthGateway>(),
      Get.find<AppErrorController>(),
      Get.find<SettingsCoordinator>(),
    ),
    permanent: true,
  );
}
```

- [ ] **Step 4: 让页面依赖 coordinator，跑页面回归**

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

Run: `timeout 60s flutter test test/pages/auth_page_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/pipeline_layout_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/pipeline_mobile_view_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/pages/settings_page_test.dart`
Expected: PASS

- [ ] **Step 5: 提交模块化装配与页面依赖切换**

```bash
git add \
  lib/app/core/di/app_bindings.dart \
  lib/app/core/di/auth_module.dart \
  lib/app/core/di/pipeline_module.dart \
  lib/app/core/di/settings_module.dart \
  lib/app/core/routing/app_routes.dart \
  lib/app/bindings.dart \
  lib/app/app.dart \
  lib/app/pages/auth_page.dart \
  lib/app/pages/pipeline_page.dart \
  lib/app/pages/settings_page.dart \
  test/pages/auth_page_test.dart \
  test/pages/pipeline_layout_test.dart \
  test/pages/pipeline_mobile_view_test.dart \
  test/pages/settings_page_test.dart
git commit -m "refactor(app): modularize bindings and route assembly"
```

### Task 7: 执行目录迁移、清理兼容层并完成最终回归

**Files:**
- Modify: `lib/app/controllers/auth_controller.dart`
- Modify: `lib/app/controllers/pipeline_controller.dart`
- Modify: `lib/app/controllers/settings_controller.dart`
- Modify: `lib/app/pages/*`
- Modify: `lib/app/widgets/*`
- Modify: `lib/app/services/*`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `test/integration/auth_pipeline_flow_test.dart`
- Reference: `test/widgets/message_viewer_card_test.dart`
- Reference: `test/widgets/message_preview_media_seek_test.dart`

- [ ] **Step 1: 使用 `git mv` 完成最终物理迁移，并保留过渡壳文件最小转发**

```bash
git mv lib/app/pages/auth_page.dart lib/app/features/auth/presentation/auth_page.dart
git mv lib/app/pages/pipeline_page.dart lib/app/features/pipeline/presentation/pipeline_page.dart
git mv lib/app/pages/pipeline_mobile_view.dart lib/app/features/pipeline/presentation/pipeline_mobile_view.dart
git mv lib/app/pages/pipeline_desktop_view.dart lib/app/features/pipeline/presentation/pipeline_desktop_view.dart
git mv lib/app/pages/settings_page.dart lib/app/features/settings/presentation/settings_page.dart
git mv lib/app/controllers/pipeline_controller.dart lib/app/features/pipeline/application/pipeline_controller_legacy.dart
git mv lib/app/controllers/settings_controller.dart lib/app/features/settings/application/settings_controller_legacy.dart
git mv lib/app/controllers/auth_controller.dart lib/app/features/auth/application/auth_controller_legacy.dart
```

- [ ] **Step 2: 在旧路径壳文件里转发到新类型，保证中间态可编译**

```dart
export 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
```

```dart
typedef AuthController = AuthCoordinator;
typedef PipelineController = PipelineCoordinator;
typedef SettingsController = SettingsCoordinator;
```

- [ ] **Step 3: 更新架构文档并移除不再需要的兼容引用**

```md
- `core/` 负责 TDLib、DI、路由与全局错误等基础设施。
- `features/auth`、`features/pipeline`、`features/settings` 分别承载独立业务边界。
- 页面依赖 coordinator，coordinator 依赖 capability interface，复杂行为下沉到服务。
```

- [ ] **Step 4: 执行最终 analyze 与关键回归**

Run: `timeout 60s dart analyze`
Expected: PASS，无新的 analyzer error

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

- [ ] **Step 5: 提交目录迁移、文档和最终收尾**

```bash
git add \
  lib/app/core \
  lib/app/features \
  lib/app/shared \
  lib/app/app.dart \
  lib/app/bindings.dart \
  docs/ARCHITECTURE.md \
  test/features \
  test/controllers \
  test/pages \
  test/widgets \
  test/integration/auth_pipeline_flow_test.dart
git commit -m "refactor: finalize steady-state architecture migration"
```

## Self-Review

### Spec coverage

- 目标结构：Task 1、Task 6、Task 7 覆盖 `core / features / shared` 与模块化装配。
- Pipeline 拆分：Task 2、Task 3 覆盖运行态、导航、动作、恢复、剩余统计与协调器。
- Telegram capability interfaces：Task 1、Task 4 覆盖边界拆分与 facade 收口。
- Settings 子系统：Task 5 覆盖 draft session、子域服务与 `AppSettings` 聚合拆分。
- 测试与回归：Task 2 到 Task 7 全部包含 focused tests、旧测试回归与最终 analyze / integration 收口。

### Placeholder scan

- 已检查全文，无 `TODO`、`TBD`、`implement later`、`待定`、`后续补上` 等占位描述。

### Type consistency

- `AuthGateway`、`SessionQueryGateway`、`MessageReadGateway`、`MediaGateway`、`ClassifyGateway`、`RecoveryGateway` 在 Task 1 定义，并在 Task 4、Task 6 中持续沿用。
- `PipelineSettingsReader` 在 Task 1 定义，并在 Task 3、Task 5 中一致使用。
- `PipelineRuntimeState`、`PipelineNavigationService`、`PipelineActionService`、`PipelineRecoveryService`、`RemainingCountService` 在 Task 2 和 Task 3 定义并在 `PipelineCoordinator` 中统一装配。
- `SettingsDraftSession` 与 `SettingsCoordinator` 在 Task 5 定义并在后续装配任务中持续使用。
