# Pipeline Coordinator Thinning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `PipelineCoordinator` 收缩为薄编排层，拆出生命周期、消息流、媒体刷新、错误映射等稳定应用层子模块。

**Architecture:** 保留 `PipelineRuntimeState` 作为共享状态容器，不改页面主入口语义。通过新增 `PipelineLifecycleCoordinator`、`PipelineFeedController`、`PipelineMediaController`、`PipelineErrorMapper` 与独立 gateway adapters，把当前 coordinator 内的大段流程逻辑按变化原因拆开。整个过程采用 TDD，先补失败测试，再最小实现，再收口 coordinator。

**Tech Stack:** Flutter、Dart 3.11、GetX、flutter_test

---

## File Map

**Create**
- `lib/app/features/pipeline/application/pipeline_error_mapper.dart`
- `lib/app/features/pipeline/application/pipeline_gateway_adapters.dart`
- `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- `lib/app/features/pipeline/application/pipeline_feed_controller.dart`
- `lib/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart`
- `test/features/pipeline/application/pipeline_error_mapper_test.dart`
- `test/features/pipeline/application/pipeline_media_controller_test.dart`
- `test/features/pipeline/application/pipeline_feed_controller_test.dart`
- `test/features/pipeline/application/pipeline_lifecycle_coordinator_test.dart`

**Modify**
- `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- `test/features/pipeline/application/pipeline_coordinator_test.dart`
- `test/controllers/pipeline_controller_test.dart`

**Verify**
- `timeout 60s dart analyze`
- `timeout 60s flutter test test/features/pipeline/application`
- `timeout 60s flutter test test/controllers/pipeline_controller_test.dart`
- `timeout 60s flutter test`

### Task 1: 提取错误映射与 gateway adapters

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_error_mapper.dart`
- Create: `lib/app/features/pipeline/application/pipeline_gateway_adapters.dart`
- Create: `test/features/pipeline/application/pipeline_error_mapper_test.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`

- [ ] **Step 1: 先写错误映射失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_error_mapper.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  test('maps flood wait to user-facing fast-operation message', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapTdlibFailure(
      TdlibFailure(code: 429, message: 'Too Many Requests: retry after 17'),
    );

    expect(resolved.title, '操作过快');
    expect(resolved.message, contains('17'));
  });

  test('maps network failure to stable offline copy', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapTdlibFailure(
      TdlibFailure(code: -1, message: 'NETWORK_ERROR'),
    );

    expect(resolved.title, '网络异常');
    expect(resolved.message, '请检查网络连接后重试');
  });
}
```

- [ ] **Step 2: 运行新测试，确认当前缺少实现**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_error_mapper_test.dart`
Expected: FAIL，提示 `PipelineErrorMapper` 文件或类型不存在

- [ ] **Step 3: 写最小实现**

```dart
class PipelineResolvedError {
  const PipelineResolvedError({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class PipelineErrorMapper {
  const PipelineErrorMapper();

  PipelineResolvedError mapTdlibFailure(TdlibFailure error) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，需等待 $waitSeconds 秒';
      return PipelineResolvedError(
        title: '操作过快',
        message: '触发 FloodWait$suffix',
      );
    }
    if (kind == TdErrorKind.network) {
      return const PipelineResolvedError(
        title: '网络异常',
        message: '请检查网络连接后重试',
      );
    }
    if (kind == TdErrorKind.auth) {
      return const PipelineResolvedError(
        title: '鉴权异常',
        message: '登录态可能失效，请重新登录',
      );
    }
    if (kind == TdErrorKind.permission) {
      return const PipelineResolvedError(
        title: '权限异常',
        message: '目标会话可能无发送权限',
      );
    }
    return PipelineResolvedError(
      title: 'TDLib 错误',
      message: error.toString(),
    );
  }

  PipelineResolvedError mapGeneralError(Object error) {
    return PipelineResolvedError(
      title: '运行异常',
      message: error.toString(),
    );
  }
}
```

- [ ] **Step 4: 抽出 gateway adapters 独立文件**

```dart
class TelegramClassifyGatewayAdapter implements ClassifyGateway {
  const TelegramClassifyGatewayAdapter(this._service);

  final TelegramGateway _service;

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) {
    return _service.classifyMessage(
      sourceChatId: sourceChatId,
      messageIds: messageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) {
    return _service.undoClassify(
      sourceChatId: sourceChatId,
      targetChatId: targetChatId,
      targetMessageIds: targetMessageIds,
    );
  }
}
```

```dart
class TelegramRecoveryGatewayAdapter implements RecoveryGateway {
  const TelegramRecoveryGatewayAdapter(this._service);

  final RecoverableClassifyGateway _service;

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    return _service.recoverPendingClassifyOperations();
  }
}
```

- [ ] **Step 5: 让 coordinator 改用新 mapper 与 adapters**

```dart
final resolvedActions =
    actions ??
    PipelineActionService(
      state: this.runtimeState,
      navigation: resolvedNavigation,
      classifyGateway: TelegramClassifyGatewayAdapter(service),
      settings: settingsReader,
      journalRepository: journalRepository,
      logs: logs,
      retryQueue: retryQueue,
    );

final resolvedRecovery =
    recovery ??
    PipelineRecoveryService(
      recoveryGateway: service is RecoverableClassifyGateway
          ? TelegramRecoveryGatewayAdapter(
              service as RecoverableClassifyGateway,
            )
          : null,
      errors: errorController,
    );
```

- [ ] **Step 6: 跑聚焦验证**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_error_mapper_test.dart`
Expected: PASS

Run: `timeout 60s dart analyze lib/app/features/pipeline/application`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_error_mapper.dart \
  lib/app/features/pipeline/application/pipeline_gateway_adapters.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  test/features/pipeline/application/pipeline_error_mapper_test.dart
git commit -m "refactor(pipeline): extract error mapper and gateway adapters"
```

### Task 2: 抽出媒体刷新控制器

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_media_controller.dart`
- Create: `test/features/pipeline/application/pipeline_media_controller_test.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`

- [ ] **Step 1: 写媒体控制器失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_refresh_service.dart';
import 'package:tgsorter/app/features/pipeline/application/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test('prepareCurrentMedia merges prepared video payload into current message', () async {
    final state = PipelineRuntimeState();
    state.currentMessage.value = PipelineMessage(
      id: 21,
      messageIds: const <int>[21],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
      ),
    );
    final controller = PipelineMediaController(
      state: state,
      mediaRefresh: _FakeMediaRefreshService(),
    );

    await controller.prepareCurrentMedia();

    expect(state.currentMessage.value?.preview.localVideoPath, 'C:/video.mp4');
  });
}

class _FakeMediaRefreshService extends PipelineMediaRefreshService {
  _FakeMediaRefreshService()
    : super(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
        localVideoPath: 'C:/video.mp4',
      ),
    );
  }
}

class _NoopMediaGateway implements MediaGateway {
  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

class _NoopMessageReadGateway implements MessageReadGateway {
  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    return const <PipelineMessage>[];
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => null;

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}
```

- [ ] **Step 2: 运行测试，确认当前缺少新控制器**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_media_controller_test.dart`
Expected: FAIL，提示 `PipelineMediaController` 不存在

- [ ] **Step 3: 写最小控制器骨架**

```dart
class PipelineMediaController {
  PipelineMediaController({
    required PipelineRuntimeState state,
    required PipelineMediaRefreshService mediaRefresh,
    Duration videoRefreshInterval = const Duration(seconds: 1),
  }) : _state = state,
       _mediaRefresh = mediaRefresh,
       _videoRefreshInterval = videoRefreshInterval;

  final PipelineRuntimeState _state;
  final PipelineMediaRefreshService _mediaRefresh;
  final Duration _videoRefreshInterval;
  Timer? _videoRefreshTimer;
  int? _refreshTargetMessageId;

  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    final message = _state.currentMessage.value;
    if (message == null || _state.videoPreparing.value) {
      return;
    }
    final requestedMessageId = targetMessageId ?? message.id;
    _refreshTargetMessageId = requestedMessageId;
    _state.videoPreparing.value = true;
    final prepared = await _mediaRefresh.prepareCurrentMedia(
      sourceChatId: message.sourceChatId,
      messageId: requestedMessageId,
    );
    _state.currentMessage.value = mergePreparedMessage(message, prepared);
  }

  PipelineMessage mergePreparedMessage(
    PipelineMessage current,
    PipelineMessage prepared,
  ) {
    return prepared;
  }

  void stop() {
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = null;
    _refreshTargetMessageId = null;
    _state.videoPreparing.value = false;
  }
}
```

- [ ] **Step 4: 把 merge / refresh / timer 逻辑完整迁入控制器**

```dart
Future<void> refreshCurrentMediaIfNeeded() async {
  final message = _state.currentMessage.value;
  if (message == null || !_needsMediaRefresh(message.preview)) {
    _state.videoPreparing.value = false;
    _refreshTargetMessageId = null;
    return;
  }
  _syncPreparingState(message.preview);
  _videoRefreshTimer?.cancel();
  _videoRefreshTimer = Timer.periodic(_videoRefreshInterval, (_) async {
    final current = _state.currentMessage.value;
    if (current == null || !_needsMediaRefresh(current.preview)) {
      stop();
      return;
    }
    final refreshMessageId = _refreshTargetMessageId ?? current.id;
    final refreshed = await _mediaRefresh.refreshCurrentMedia(
      sourceChatId: current.sourceChatId,
      messageId: refreshMessageId,
    );
    final merged = mergePreparedMessage(current, refreshed);
    _state.currentMessage.value = merged;
    _syncPreparingState(merged.preview);
    if (!_needsMediaRefresh(merged.preview)) {
      stop();
    }
  });
}
```

- [ ] **Step 5: 让 coordinator 只转发媒体入口**

```dart
Future<void> prepareCurrentMedia([int? targetMessageId]) {
  return mediaController.prepareCurrentMedia(targetMessageId);
}

Future<void> _refreshCurrentMediaIfNeeded() {
  return mediaController.refreshCurrentMediaIfNeeded();
}

void _stopVideoRefresh() {
  mediaController.stop();
}
```

- [ ] **Step 6: 跑聚焦验证**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_media_controller_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_media_controller.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  test/features/pipeline/application/pipeline_media_controller_test.dart \
  test/controllers/pipeline_controller_test.dart
git commit -m "refactor(pipeline): extract media controller"
```

### Task 3: 抽出消息流控制器

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_feed_controller.dart`
- Create: `test/features/pipeline/application/pipeline_feed_controller_test.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 写 feed 控制器失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_feed_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/features/pipeline/application/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/media_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

void main() {
  test('loadInitialMessages replaces cache and records tail message id', () async {
    final state = PipelineRuntimeState();
    final navigation = PipelineNavigationService(state: state);
    final controller = PipelineFeedController(
      state: state,
      navigation: navigation,
      messages: _FakeMessageReadGateway(),
      settings: _FakeSettingsReader(),
      remainingCount: _FakeRemainingCountService(),
    );

    await controller.loadInitialMessages();

    expect(state.currentMessage.value?.id, 1);
    expect(controller.tailMessageId, 2);
  });
}

class _FakeMessageReadGateway implements MessageReadGateway {
  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    return <PipelineMessage>[
      PipelineMessage(
        id: 1,
        messageIds: const <int>[1],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: 'first',
        ),
      ),
      PipelineMessage(
        id: 2,
        messageIds: const <int>[2],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: 'second',
        ),
      ),
    ];
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 8;

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => null;

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeMediaGateway implements MediaGateway {
  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSettingsReader implements PipelineSettingsReader {
  @override
  final settingsStream = const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 8888,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: false,
    batchSize: 2,
    throttleMs: 0,
    proxy: ProxySettings.empty,
  ).obs;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    throw UnimplementedError();
  }
}

class _FakeRemainingCountService extends RemainingCountService {}
```

- [ ] **Step 2: 运行测试，确认当前实现缺失**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_feed_controller_test.dart`
Expected: FAIL，提示 `PipelineFeedController` 不存在

- [ ] **Step 3: 写最小 feed 控制器骨架**

```dart
class PipelineFeedController {
  static const int messagePageSize = 20;

  PipelineFeedController({
    required PipelineRuntimeState state,
    required PipelineNavigationService navigation,
    required MessageReadGateway messages,
    required MediaGateway media,
    required PipelineSettingsReader settings,
    required RemainingCountService remainingCount,
    required void Function(Object error) reportGeneralError,
  }) : _state = state,
       _navigation = navigation,
       _messages = messages,
       _media = media,
       _settings = settings,
       _remainingCount = remainingCount,
       _reportGeneralError = reportGeneralError;

  final PipelineRuntimeState _state;
  final PipelineNavigationService _navigation;
  final MessageReadGateway _messages;
  final MediaGateway _media;
  final PipelineSettingsReader _settings;
  final RemainingCountService _remainingCount;
  final void Function(Object error) _reportGeneralError;
  int? tailMessageId;
  final Set<int> _previewPreparedMessageIds = <int>{};
}
```

- [ ] **Step 4: 迁入 load / append / ensure visible / prefetch / remaining count 逻辑**

```dart
Future<void> loadInitialMessages() async {
  unawaited(refreshRemainingCount());
  _navigation.replaceMessages(const <PipelineMessage>[]);
  _previewPreparedMessageIds.clear();
  tailMessageId = null;
  final page = await _messages.fetchMessagePage(
    direction: _settings.currentSettings.fetchDirection,
    sourceChatId: _settings.currentSettings.sourceChatId,
    fromMessageId: null,
    limit: messagePageSize,
  );
  _navigation.replaceMessages(page);
  tailMessageId = page.isEmpty ? null : page.last.id;
  if (page.isNotEmpty) {
    await prepareUpcomingPreviews();
  }
}
```

```dart
Future<void> ensureVisibleMessage() async {
  if (_navigation.isEmpty) {
    await appendMoreMessages();
  }
  _navigation.ensureCurrentAndSync();
}
```

- [ ] **Step 5: coordinator 改为委托 feed 控制器**

```dart
Future<void> fetchNext() async {
  mediaController.stop();
  loading.value = true;
  try {
    await feedController.loadInitialMessages();
    await mediaController.refreshCurrentMediaIfNeeded();
  } on TdlibFailure catch (error) {
    _reportTdlibFailure(error);
  } catch (error) {
    _reportGeneralError(error);
  } finally {
    loading.value = false;
  }
}
```

- [ ] **Step 6: 跑聚焦验证**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_feed_controller_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_feed_controller.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  test/features/pipeline/application/pipeline_feed_controller_test.dart \
  test/controllers/pipeline_controller_test.dart
git commit -m "refactor(pipeline): extract feed controller"
```

### Task 4: 抽出生命周期协调器并瘦身 PipelineCoordinator

**Files:**
- Create: `lib/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart`
- Create: `test/features/pipeline/application/pipeline_lifecycle_coordinator_test.dart`
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Modify: `test/features/pipeline/application/pipeline_coordinator_test.dart`
- Modify: `test/controllers/pipeline_controller_test.dart`

- [ ] **Step 1: 写生命周期协调器失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/recovery_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

void main() {
  test('settings change resets pipeline only when source or direction changes', () {
    var didReset = false;
    final lifecycle = PipelineLifecycleCoordinator(
      state: PipelineRuntimeState(),
      settings: _FakeSettingsReader(),
      recovery: _FakeRecoveryService(),
      onFetchNext: () async {},
      onResetPipeline: () {
        didReset = true;
      },
    );

    lifecycle.handleSettingsChanged(_updatedSettings());

    expect(didReset, isTrue);
  });
}

AppSettings _updatedSettings() {
  return const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 9999,
    fetchDirection: MessageFetchDirection.oldestFirst,
    forwardAsCopy: false,
    batchSize: 2,
    throttleMs: 0,
    proxy: ProxySettings.empty,
  );
}

class _FakeSettingsReader implements PipelineSettingsReader {
  @override
  final settingsStream = const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: 8888,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: false,
    batchSize: 2,
    throttleMs: 0,
    proxy: ProxySettings.empty,
  ).obs;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    throw UnimplementedError();
  }
}

class _FakeRecoveryService extends PipelineRecoveryService {
  _FakeRecoveryService()
    : super(
        recoveryGateway: _NoopRecoveryGateway(),
        errors: AppErrorController(),
      );

  @override
  bool get isCompleted => true;
}

class _NoopRecoveryGateway implements RecoveryGateway {
  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    return ClassifyRecoverySummary.empty;
  }
}
```

- [ ] **Step 2: 运行测试，确认当前无此实现**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_lifecycle_coordinator_test.dart`
Expected: FAIL，提示 `PipelineLifecycleCoordinator` 不存在

- [ ] **Step 3: 写最小生命周期协调器骨架**

```dart
class PipelineLifecycleCoordinator {
  PipelineLifecycleCoordinator({
    required PipelineRuntimeState state,
    required PipelineSettingsReader settings,
    required PipelineRecoveryService recovery,
    required Future<void> Function() onFetchNext,
    required void Function() onResetPipeline,
  }) : _state = state,
       _settings = settings,
       _recovery = recovery,
       _onFetchNext = onFetchNext,
       _onResetPipeline = onResetPipeline {
    _lastFetchDirection = settings.currentSettings.fetchDirection;
    _lastSourceChatId = settings.currentSettings.sourceChatId;
  }

  final PipelineRuntimeState _state;
  final PipelineSettingsReader _settings;
  final PipelineRecoveryService _recovery;
  final Future<void> Function() _onFetchNext;
  final void Function() _onResetPipeline;
  bool _isAuthorized = false;
  MessageFetchDirection? _lastFetchDirection;
  int? _lastSourceChatId;

  void updateConnection(bool isReady) {
    _state.isOnline.value = isReady;
    tryAutoFetchNext();
  }
}
```

- [ ] **Step 4: 迁入 auth / connection / settings / auto fetch / recovery 逻辑**

```dart
void updateAuthorization(bool isReady) {
  _isAuthorized = isReady;
  tryAutoFetchNext();
}

void tryAutoFetchNext() {
  if (!_isAuthorized || !_state.isOnline.value || _state.loading.value) {
    return;
  }
  if (!_recovery.isCompleted) {
    triggerTransactionRecoveryIfNeeded();
    return;
  }
  if (_state.currentMessage.value != null) {
    return;
  }
  unawaited(_onFetchNext());
}
```

```dart
void handleSettingsChanged(AppSettings settings) {
  final directionChanged = settings.fetchDirection != _lastFetchDirection;
  final sourceChanged = settings.sourceChatId != _lastSourceChatId;
  _lastFetchDirection = settings.fetchDirection;
  _lastSourceChatId = settings.sourceChatId;
  if (!directionChanged && !sourceChanged) {
    return;
  }
  _onResetPipeline();
  tryAutoFetchNext();
}
```

- [ ] **Step 5: 让 coordinator 成为薄 façade**

```dart
@override
void onInit() {
  super.onInit();
  logs.assignAll(_journalRepository.loadLogs());
  retryQueue.assignAll(_journalRepository.loadRetryQueue());
  _connectionSub = _service.connectionStates.listen((state) {
    isOnline.value = state.isReady;
    lifecycle.updateConnection(state.isReady);
  });
  _authSub = _service.authStates.listen((state) {
    lifecycle.updateAuthorization(state.isReady);
  });
  _settingsWorker = ever<AppSettings>(
    _settingsReader.settingsStream,
    lifecycle.handleSettingsChanged,
  );
}
```

- [ ] **Step 6: 把 coordinator 测试改为薄编排语义**

```dart
test('coordinator fetchNext delegates message load to feed controller', () async {
  final harness = _PipelineCoordinatorHarness();

  await harness.coordinator.fetchNext();

  expect(harness.feed.loadInitialMessagesCalls, 1);
});
```

```dart
test('coordinator onInit wires auth and connection events through lifecycle', () async {
  final harness = _PipelineCoordinatorHarness();

  harness.service.emitConnectionReady();
  harness.service.emitAuthReady();

  expect(harness.lifecycle.connectionUpdates, 1);
  expect(harness.lifecycle.authorizationUpdates, 1);
});
```

- [ ] **Step 7: 跑聚焦验证**

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_lifecycle_coordinator_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/features/pipeline/application/pipeline_coordinator_test.dart`
Expected: PASS

Run: `timeout 60s flutter test test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 8: 提交**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  test/features/pipeline/application/pipeline_lifecycle_coordinator_test.dart \
  test/features/pipeline/application/pipeline_coordinator_test.dart \
  test/controllers/pipeline_controller_test.dart
git commit -m "refactor(pipeline): thin coordinator into lifecycle facade"
```

### Task 5: 全量回归与结构验收

**Files:**
- Modify: `lib/app/features/pipeline/application/pipeline_coordinator.dart`
- Verify: `test/features/pipeline/application/*`
- Verify: `test/controllers/pipeline_controller_test.dart`
- Verify: `test/pages/*`
- Verify: `test/integration/auth_pipeline_flow_test.dart`

- [ ] **Step 1: 跑静态检查**

Run: `timeout 60s dart analyze`
Expected: PASS，输出 `No issues found!`

- [ ] **Step 2: 跑 pipeline application 全量测试**

Run: `timeout 60s flutter test test/features/pipeline/application`
Expected: PASS

- [ ] **Step 3: 跑 controller 回归**

Run: `timeout 60s flutter test test/controllers/pipeline_controller_test.dart`
Expected: PASS

- [ ] **Step 4: 跑页面与集成回归**

Run: `timeout 60s flutter test test/pages`
Expected: PASS

Run: `timeout 60s flutter test test/integration/auth_pipeline_flow_test.dart`
Expected: PASS

- [ ] **Step 5: 跑整仓回归**

Run: `timeout 60s flutter test`
Expected: PASS，最后输出 `All tests passed!`

- [ ] **Step 6: 验证 coordinator 已显著瘦身**

Run: `wc -l lib/app/features/pipeline/application/pipeline_coordinator.dart`
Expected: 输出显著低于当前约 800 行，且主文件不再包含 gateway adapter 类

- [ ] **Step 7: 提交**

```bash
git add \
  lib/app/features/pipeline/application/pipeline_coordinator.dart \
  lib/app/features/pipeline/application/pipeline_lifecycle_coordinator.dart \
  lib/app/features/pipeline/application/pipeline_feed_controller.dart \
  lib/app/features/pipeline/application/pipeline_media_controller.dart \
  lib/app/features/pipeline/application/pipeline_error_mapper.dart \
  lib/app/features/pipeline/application/pipeline_gateway_adapters.dart \
  test/features/pipeline/application \
  test/controllers/pipeline_controller_test.dart
git commit -m "refactor(pipeline): complete coordinator thinning"
```

## Self-Review

- Spec coverage:
  - 生命周期拆分：Task 4 覆盖
  - 消息流拆分：Task 3 覆盖
  - 媒体刷新拆分：Task 2 覆盖
  - 错误映射与 adapter 拆分：Task 1 覆盖
  - coordinator 薄化与回归：Task 4、Task 5 覆盖
- Placeholder scan:
  - 除本节自检说明外，无 `TODO`、`TBD`、`later`、`适当处理` 等占位描述
- Type consistency:
  - 新类型名称统一使用 `PipelineErrorMapper`、`PipelineMediaController`、`PipelineFeedController`、`PipelineLifecycleCoordinator`
