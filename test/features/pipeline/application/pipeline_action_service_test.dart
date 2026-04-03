import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_action_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  test('classify success appends log and removes current message', () async {
    final harness = _PipelineActionHarness.success();
    final service = harness.build();

    final ok = await service.classifyCurrent('work');

    expect(ok, isTrue);
    expect(harness.appendedLogs.single.status, ClassifyOperationStatus.success);
    expect(harness.removedCurrentMessage, isTrue);
  });
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

  final PipelineRuntimeState state;
  final _TrackingNavigationService navigation;
  final _FakeClassifyGateway classifyGateway;
  final _FakeSettingsReader settingsReader;
  final _FakeOperationJournalRepository journalRepository;

  List<ClassifyOperationLog> get appendedLogs => journalRepository.savedLogs;
  bool get removedCurrentMessage => navigation.removedCurrentMessage;

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
  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
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
  }) {
    throw UnimplementedError();
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
