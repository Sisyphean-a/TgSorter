import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_action_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  test('classify success appends log and removes current message', () async {
    final harness = _PipelineActionHarness.success();
    final service = harness.build();

    final receipt = await service.classifyCurrent(
      'work',
      logs: harness.logs,
      retryQueue: harness.retryQueue,
    );

    expect(receipt, isNotNull);
    expect(harness.appendedLogs.single.status, ClassifyOperationStatus.success);
    expect(harness.removedCurrentMessage, isTrue);
  });

  test('skipCurrent appends skipped log and removes current message', () async {
    final harness = _PipelineActionHarness.success();
    final service = harness.build();

    final skipped = await service.skipCurrent(
      source: 'shortcut',
      logs: harness.logs,
    );

    expect(skipped, isTrue);
    expect(harness.appendedLogs.single.status, ClassifyOperationStatus.skipped);
    expect(harness.appendedLogs.single.reason, 'shortcut');
    expect(harness.removedCurrentMessage, isTrue);
  });

  test('classify failure appends failure log and enqueues retry', () async {
    final harness = _PipelineActionHarness.failure();
    final service = harness.build();

    await expectLater(
      () => service.classifyCurrent(
        'work',
        logs: harness.logs,
        retryQueue: harness.retryQueue,
      ),
      throwsA(isA<TdlibFailure>()),
    );

    expect(harness.appendedLogs.single.status, ClassifyOperationStatus.failed);
    expect(harness.savedRetryQueue.single.messageIds, <int>[21]);
    expect(harness.removedCurrentMessage, isFalse);
  });

  test('undoLastSuccess appends undo log', () async {
    final harness = _PipelineActionHarness.success();
    final service = harness.build();

    final undone = await service.undoLastSuccess(
      receipt: ClassifyReceipt(
        sourceChatId: 8888,
        sourceMessageIds: <int>[21, 22],
        targetChatId: 10001,
        targetMessageIds: <int>[1021, 1022],
      ),
      logs: harness.logs,
    );

    expect(undone, isTrue);
    expect(harness.undoCalls, 1);
    expect(
      harness.appendedLogs.single.status,
      ClassifyOperationStatus.undoSuccess,
    );
  });

  test(
    'retryNextFailed removes queue head and appends retry success log',
    () async {
      final harness = _PipelineActionHarness.success();
      final service = harness.build();
      harness.retryQueue.add(
        RetryQueueItem(
          id: 'retry-21',
          categoryKey: 'work',
          sourceChatId: 8888,
          messageIds: const <int>[21],
          targetChatId: 10001,
          createdAtMs: 1,
          reason: 'network',
        ),
      );

      final retried = await service.retryNextFailed(
        retryQueue: harness.retryQueue,
        logs: harness.logs,
      );

      expect(retried, isTrue);
      expect(harness.retryQueue, isEmpty);
      expect(
        harness.appendedLogs.single.status,
        ClassifyOperationStatus.retrySuccess,
      );
    },
  );
}

class _PipelineActionHarness {
  _PipelineActionHarness._({
    required this.state,
    required this.navigation,
    required this.classifyGateway,
    required this.settingsReader,
    required this.journalRepository,
  });

  factory _PipelineActionHarness.success() {
    final state = PipelineRuntimeState();
    final navigation = _TrackingNavigationService(state: state);
    final classifyGateway = _FakeClassifyGateway();
    final settingsReader = _FakeSettingsReader();
    final journalRepository = _FakeOperationJournalRepository();
    final message = _fakePipelineMessage(id: 21);
    navigation.replaceMessages(<PipelineMessage>[message]);
    return _PipelineActionHarness._(
      state: state,
      navigation: navigation,
      classifyGateway: classifyGateway,
      settingsReader: settingsReader,
      journalRepository: journalRepository,
    );
  }

  factory _PipelineActionHarness.failure() {
    final state = PipelineRuntimeState();
    final navigation = _TrackingNavigationService(state: state);
    final classifyGateway = _FakeClassifyGateway(
      classifyFailure: TdlibFailure.transport(
        message: 'offline',
        request: 'forwardMessages',
        phase: TdlibPhase.business,
      ),
    );
    final settingsReader = _FakeSettingsReader();
    final journalRepository = _FakeOperationJournalRepository();
    final message = _fakePipelineMessage(id: 21);
    navigation.replaceMessages(<PipelineMessage>[message]);
    return _PipelineActionHarness._(
      state: state,
      navigation: navigation,
      classifyGateway: classifyGateway,
      settingsReader: settingsReader,
      journalRepository: journalRepository,
    );
  }

  final PipelineRuntimeState state;
  final _TrackingNavigationService navigation;
  final _FakeClassifyGateway classifyGateway;
  final _FakeSettingsReader settingsReader;
  final _FakeOperationJournalRepository journalRepository;
  final logs = <ClassifyOperationLog>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;

  List<ClassifyOperationLog> get appendedLogs => journalRepository.savedLogs;
  List<RetryQueueItem> get savedRetryQueue => journalRepository.savedRetryQueue;
  bool get removedCurrentMessage => navigation.removedCurrentMessage;
  int get undoCalls => classifyGateway.undoCalls;

  PipelineActionService build() {
    return PipelineActionService(
      state: state,
      navigation: navigation,
      classifyGateway: classifyGateway,
      settings: settingsReader,
      journalRepository: journalRepository,
    );
  }
}

class _TrackingNavigationService extends PipelineNavigationService {
  _TrackingNavigationService({required super.state});

  bool removedCurrentMessage = false;

  @override
  void removeCurrentAndSync() {
    removedCurrentMessage = true;
    super.removeCurrentAndSync();
  }
}

class _FakeClassifyGateway implements ClassifyGateway {
  _FakeClassifyGateway({this.classifyFailure});

  final TdlibFailure? classifyFailure;
  int undoCalls = 0;

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    final failure = classifyFailure;
    if (failure != null) {
      throw failure;
    }
    return ClassifyReceipt(
      sourceChatId: sourceChatId ?? 0,
      sourceMessageIds: messageIds,
      targetChatId: targetChatId,
      targetMessageIds: messageIds.map((item) => item + 1000).toList(),
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {
    undoCalls++;
  }
}

class _FakeSettingsReader implements PipelineSettingsReader {
  @override
  final Rx<AppSettings> settingsStream = const AppSettings(
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
  final List<ClassifyOperationLog> savedLogs = <ClassifyOperationLog>[];
  final List<RetryQueueItem> savedRetryQueue = <RetryQueueItem>[];
  final List<RetryQueueItem> _retryQueue = <RetryQueueItem>[];
  final List<ClassifyTransactionEntry> _transactions =
      <ClassifyTransactionEntry>[];

  @override
  List<ClassifyOperationLog> loadLogs() =>
      List<ClassifyOperationLog>.from(savedLogs);

  @override
  Future<void> saveLogs(List<ClassifyOperationLog> logs) async {
    savedLogs
      ..clear()
      ..addAll(logs);
  }

  @override
  List<RetryQueueItem> loadRetryQueue() =>
      List<RetryQueueItem>.from(_retryQueue);

  @override
  Future<void> saveRetryQueue(List<RetryQueueItem> items) async {
    savedRetryQueue
      ..clear()
      ..addAll(items);
    _retryQueue
      ..clear()
      ..addAll(items);
  }

  @override
  List<ClassifyTransactionEntry> loadClassifyTransactions() {
    return List<ClassifyTransactionEntry>.from(_transactions);
  }

  @override
  Future<void> saveClassifyTransactions(
    List<ClassifyTransactionEntry> items,
  ) async {
    _transactions
      ..clear()
      ..addAll(items);
  }

  @override
  Future<void> upsertClassifyTransaction(ClassifyTransactionEntry entry) async {
    final index = _transactions.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      _transactions.add(entry);
      return;
    }
    _transactions[index] = entry;
  }

  @override
  Future<void> removeClassifyTransaction(String id) async {
    _transactions.removeWhere((item) => item.id == id);
  }
}

PipelineMessage _fakePipelineMessage({required int id}) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: '$id'),
  );
}
