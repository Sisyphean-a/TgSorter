import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_action_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_refresh_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/recovery_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  test('coordinator classify delegates to action service', () async {
    final harness = _PipelineCoordinatorHarness();
    harness.runtimeState.isOnline.value = true;
    harness.runtimeState.currentMessage.value = _textMessage(21, 'current');

    final ok = await harness.coordinator.classify('work');

    expect(ok, isTrue);
    expect(harness.actions.classifyCalls, 1);
    expect(harness.actions.lastCategoryKey, 'work');
  });

  test('coordinator prepareCurrentMedia delegates to media refresh service', () async {
    final harness = _PipelineCoordinatorHarness();
    harness.runtimeState.currentMessage.value = PipelineMessage(
      id: 21,
      messageIds: const <int>[21],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
      ),
    );

    await harness.coordinator.prepareCurrentMedia(21);

    expect(harness.mediaRefresh.prepareCalls, 1);
    expect(harness.runtimeState.currentMessage.value?.id, 21);
  });

  test('coordinator showNextMessage delegates to navigation service', () async {
    final harness = _PipelineCoordinatorHarness();
    harness.navigation.replaceMessages(<PipelineMessage>[
      _textMessage(1, 'first'),
      _textMessage(2, 'second'),
    ]);

    await harness.coordinator.showNextMessage();

    expect(harness.runtimeState.currentMessage.value?.id, 2);
  });

  test('coordinator recoverPendingTransactions delegates to recovery service', () async {
    final harness = _PipelineCoordinatorHarness();

    await harness.coordinator.recoverPendingTransactionsIfNeeded();

    expect(harness.recovery.recoverCalls, 1);
  });
}

class _PipelineCoordinatorHarness {
  factory _PipelineCoordinatorHarness() {
    final runtimeState = PipelineRuntimeState();
    final navigation = PipelineNavigationService(state: runtimeState);
    final actions = _RecordingPipelineActionService(
      state: runtimeState,
      navigation: navigation,
    );
    final recovery = _RecordingPipelineRecoveryService();
    final mediaRefresh = _RecordingPipelineMediaRefreshService();
    return _PipelineCoordinatorHarness._(
      runtimeState: runtimeState,
      navigation: navigation,
      actions: actions,
      recovery: recovery,
      mediaRefresh: mediaRefresh,
      remainingCount: RemainingCountService(),
    );
  }

  _PipelineCoordinatorHarness._({
    required this.runtimeState,
    required this.navigation,
    required this.actions,
    required this.recovery,
    required this.mediaRefresh,
    required this.remainingCount,
  }) {
    coordinator = PipelineCoordinator(
      service: _NoopTelegramGateway(),
      settingsReader: _FakeSettingsReader(),
      journalRepository: _FakeOperationJournalRepository(),
      errorController: AppErrorController(),
      runtimeState: runtimeState,
      navigation: navigation,
      actions: actions,
      recovery: recovery,
      mediaRefresh: mediaRefresh,
      remainingCountService: remainingCount,
    );
  }

  final PipelineRuntimeState runtimeState;
  final PipelineNavigationService navigation;
  final RemainingCountService remainingCount;
  final _RecordingPipelineActionService actions;
  final _RecordingPipelineRecoveryService recovery;
  final _RecordingPipelineMediaRefreshService mediaRefresh;
  late final PipelineCoordinator coordinator;
}

class _RecordingPipelineActionService extends PipelineActionService {
  _RecordingPipelineActionService({
    required super.state,
    required super.navigation,
  }) : super(
         classifyGateway: _NoopClassifyGateway(),
         settings: _FakeSettingsReader(),
         journalRepository: _FakeOperationJournalRepository(),
       );

  int classifyCalls = 0;
  String? lastCategoryKey;

  @override
  Future<ClassifyReceipt?> classifyCurrent(
    String key, {
    List<ClassifyOperationLog>? logs,
    List<RetryQueueItem>? retryQueue,
    PipelineActionIdBuilder? idBuilder,
    PipelineActionNowMs? nowMs,
  }) async {
    classifyCalls++;
    lastCategoryKey = key;
    return const ClassifyReceipt(
      sourceChatId: 8888,
      sourceMessageIds: <int>[21],
      targetChatId: 10001,
      targetMessageIds: <int>[1021],
    );
  }
}

class _RecordingPipelineMediaRefreshService extends PipelineMediaRefreshService {
  _RecordingPipelineMediaRefreshService()
    : super(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  int prepareCalls = 0;

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    prepareCalls++;
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
      ),
    );
  }
}

class _RecordingPipelineRecoveryService extends PipelineRecoveryService {
  _RecordingPipelineRecoveryService()
    : super(
        recoveryGateway: _NoopRecoveryGateway(),
        errors: AppErrorController(),
      );

  int recoverCalls = 0;

  @override
  Future<void> recoverPendingTransactionsIfNeeded() async {
    recoverCalls++;
  }
}

class _FakeSettingsReader implements PipelineSettingsReader {
  @override
  final settingsStream = const AppSettings(
    categories: <CategoryConfig>[
      CategoryConfig(key: 'work', targetChatId: 10001, targetChatTitle: '工作'),
    ],
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
    return currentSettings.categories.firstWhere((item) => item.key == key);
  }
}

class _FakeOperationJournalRepository implements OperationJournalRepository {
  final List<ClassifyOperationLog> _logs = <ClassifyOperationLog>[];
  final List<RetryQueueItem> _retryQueue = <RetryQueueItem>[];

  @override
  List<ClassifyOperationLog> loadLogs() => List<ClassifyOperationLog>.from(_logs);

  @override
  Future<void> saveLogs(List<ClassifyOperationLog> logs) async {
    _logs
      ..clear()
      ..addAll(logs);
  }

  @override
  List<RetryQueueItem> loadRetryQueue() =>
      List<RetryQueueItem>.from(_retryQueue);

  @override
  Future<void> saveRetryQueue(List<RetryQueueItem> items) async {
    _retryQueue
      ..clear()
      ..addAll(items);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError();
  }
}

class _NoopClassifyGateway implements ClassifyGateway {
  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) {
    throw UnimplementedError();
  }
}

class _NoopMediaGateway implements MediaGateway {
  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }

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
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

class _NoopRecoveryGateway implements RecoveryGateway {
  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    throw UnimplementedError();
  }
}

class _NoopTelegramGateway implements TelegramGateway {
  @override
  Stream<TdAuthState> get authStates => const Stream<TdAuthState>.empty();

  @override
  Stream<TdConnectionState> get connectionStates =>
      const Stream<TdConnectionState>.empty();

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    return ClassifyRecoverySummary.empty;
  }

  @override
  Future<void> restart() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}
}

PipelineMessage _textMessage(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}
