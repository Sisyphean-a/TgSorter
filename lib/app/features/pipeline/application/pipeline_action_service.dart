import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

import 'classify_gateway.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';
import 'pipeline_settings_reader.dart';

typedef PipelineActionIdBuilder = String Function(String prefix, int messageId);
typedef PipelineActionNowMs = int Function();

class PipelineActionService {
  PipelineActionService({
    required PipelineRuntimeState state,
    required PipelineNavigationService navigation,
    required ClassifyGateway classifyGateway,
    required PipelineSettingsReader settings,
    required OperationJournalRepository journalRepository,
    List<ClassifyOperationLog>? logs,
    List<RetryQueueItem>? retryQueue,
  }) : _state = state,
       _navigation = navigation,
       _classifyGateway = classifyGateway,
       _settings = settings,
       _journalRepository = journalRepository,
       _logs = logs,
       _retryQueue = retryQueue;

  final PipelineRuntimeState _state;
  final PipelineNavigationService _navigation;
  final ClassifyGateway _classifyGateway;
  final PipelineSettingsReader _settings;
  final OperationJournalRepository _journalRepository;
  final List<ClassifyOperationLog>? _logs;
  final List<RetryQueueItem>? _retryQueue;
  ClassifyReceipt? _lastReceipt;

  ClassifyReceipt? get lastReceipt => _lastReceipt;

  Future<ClassifyReceipt?> classifyCurrent(
    String key, {
    List<ClassifyOperationLog>? logs,
    List<RetryQueueItem>? retryQueue,
    PipelineActionIdBuilder? idBuilder,
    PipelineActionNowMs? nowMs,
  }) async {
    final message = _state.currentMessage.value;
    if (message == null || _state.processing.value) {
      return null;
    }
    final target = _settings.getCategory(key);
    final logStore = logs ?? _logs ?? <ClassifyOperationLog>[];
    final retryStore = retryQueue ?? _retryQueue ?? <RetryQueueItem>[];
    final buildId = idBuilder ?? _defaultIdBuilder;
    final createdAtMs = nowMs ?? _defaultNowMs;
    _state.processing.value = true;
    try {
      final receipt = await _classifyGateway.classifyMessage(
        sourceChatId: message.sourceChatId,
        messageIds: message.messageIds,
        targetChatId: target.targetChatId,
        asCopy: _settings.currentSettings.forwardAsCopy,
      );
      _lastReceipt = receipt;
      await _appendLog(
        logStore,
        ClassifyOperationLog(
          id: buildId('ok', message.id),
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId,
          createdAtMs: createdAtMs(),
          status: ClassifyOperationStatus.success,
        ),
      );
      _navigation.removeCurrentAndSync();
      return receipt;
    } on TdlibFailure catch (error) {
      await _appendLog(
        logStore,
        ClassifyOperationLog(
          id: buildId('fail', message.id),
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId,
          createdAtMs: createdAtMs(),
          status: ClassifyOperationStatus.failed,
          reason: error.toString(),
        ),
      );
      await _enqueueRetry(
        retryStore,
        RetryQueueItem(
          id: buildId('retry', message.id),
          categoryKey: key,
          sourceChatId: message.sourceChatId,
          messageIds: message.messageIds,
          targetChatId: target.targetChatId,
          createdAtMs: createdAtMs(),
          reason: error.toString(),
        ),
      );
      rethrow;
    } finally {
      _state.processing.value = false;
    }
  }

  Future<bool> skipCurrent({
    String source = 'unknown',
    List<ClassifyOperationLog>? logs,
    PipelineActionIdBuilder? idBuilder,
    PipelineActionNowMs? nowMs,
  }) async {
    final message = _state.currentMessage.value;
    if (message == null || _state.processing.value) {
      return false;
    }
    final logStore = logs ?? _logs ?? <ClassifyOperationLog>[];
    final buildId = idBuilder ?? _defaultIdBuilder;
    final createdAtMs = nowMs ?? _defaultNowMs;
    await _appendLog(
      logStore,
      ClassifyOperationLog(
        id: buildId('skip', message.id),
        categoryKey: '-',
        messageId: message.id,
        targetChatId: 0,
        createdAtMs: createdAtMs(),
        status: ClassifyOperationStatus.skipped,
        reason: source,
      ),
    );
    _navigation.removeCurrentAndSync();
    return true;
  }

  Future<bool> undoLastSuccess({
    required ClassifyReceipt receipt,
    List<ClassifyOperationLog>? logs,
    PipelineActionIdBuilder? idBuilder,
    PipelineActionNowMs? nowMs,
  }) async {
    if (_state.processing.value) {
      return false;
    }
    final logStore = logs ?? _logs ?? <ClassifyOperationLog>[];
    final buildId = idBuilder ?? _defaultIdBuilder;
    final createdAtMs = nowMs ?? _defaultNowMs;
    _state.processing.value = true;
    try {
      await _classifyGateway.undoClassify(
        sourceChatId: receipt.sourceChatId,
        targetChatId: receipt.targetChatId,
        targetMessageIds: receipt.targetMessageIds,
      );
      await _appendLog(
        logStore,
        ClassifyOperationLog(
          id: buildId('undo_ok', receipt.primarySourceMessageId),
          categoryKey: '-',
          messageId: receipt.primarySourceMessageId,
          targetChatId: receipt.targetChatId,
          createdAtMs: createdAtMs(),
          status: ClassifyOperationStatus.undoSuccess,
        ),
      );
      return true;
    } on TdlibFailure catch (error) {
      await _appendLog(
        logStore,
        ClassifyOperationLog(
          id: buildId('undo_fail', receipt.primarySourceMessageId),
          categoryKey: '-',
          messageId: receipt.primarySourceMessageId,
          targetChatId: receipt.targetChatId,
          createdAtMs: createdAtMs(),
          status: ClassifyOperationStatus.undoFailed,
          reason: error.toString(),
        ),
      );
      rethrow;
    } finally {
      _state.processing.value = false;
    }
  }

  Future<bool> retryNextFailed({
    List<RetryQueueItem>? retryQueue,
    List<ClassifyOperationLog>? logs,
    PipelineActionIdBuilder? idBuilder,
    PipelineActionNowMs? nowMs,
  }) async {
    final logStore = logs ?? _logs ?? <ClassifyOperationLog>[];
    final retryStore = retryQueue ?? _retryQueue ?? <RetryQueueItem>[];
    if (_state.processing.value || retryStore.isEmpty) {
      return false;
    }
    final item = retryStore.first;
    final buildId = idBuilder ?? _defaultIdBuilder;
    final createdAtMs = nowMs ?? _defaultNowMs;
    _state.processing.value = true;
    try {
      await _classifyGateway.classifyMessage(
        sourceChatId: item.sourceChatId ?? _settings.currentSettings.sourceChatId,
        messageIds: item.messageIds,
        targetChatId: item.targetChatId,
        asCopy: _settings.currentSettings.forwardAsCopy,
      );
      retryStore.removeAt(0);
      await _journalRepository.saveRetryQueue(
        List<RetryQueueItem>.from(retryStore),
      );
      await _appendLog(
        logStore,
        ClassifyOperationLog(
          id: buildId('retry_ok', item.primaryMessageId),
          categoryKey: item.categoryKey,
          messageId: item.primaryMessageId,
          targetChatId: item.targetChatId,
          createdAtMs: createdAtMs(),
          status: ClassifyOperationStatus.retrySuccess,
        ),
      );
      return true;
    } on TdlibFailure catch (error) {
      retryStore
        ..removeAt(0)
        ..add(item);
      await _journalRepository.saveRetryQueue(
        List<RetryQueueItem>.from(retryStore),
      );
      await _appendLog(
        logStore,
        ClassifyOperationLog(
          id: buildId('retry_fail', item.primaryMessageId),
          categoryKey: item.categoryKey,
          messageId: item.primaryMessageId,
          targetChatId: item.targetChatId,
          createdAtMs: createdAtMs(),
          status: ClassifyOperationStatus.retryFailed,
          reason: error.toString(),
        ),
      );
      rethrow;
    } finally {
      _state.processing.value = false;
    }
  }

  Future<void> _appendLog(
    List<ClassifyOperationLog> logs,
    ClassifyOperationLog log,
  ) async {
    logs.insert(0, log);
    await _journalRepository.saveLogs(List<ClassifyOperationLog>.from(logs));
  }

  Future<void> _enqueueRetry(
    List<RetryQueueItem> retryQueue,
    RetryQueueItem item,
  ) async {
    retryQueue.add(item);
    await _journalRepository.saveRetryQueue(List<RetryQueueItem>.from(retryQueue));
  }

  static String _defaultIdBuilder(String prefix, int messageId) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$messageId-$now';
  }

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;
}
