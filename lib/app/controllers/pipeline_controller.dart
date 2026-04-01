import 'dart:async';

import 'package:get/get.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class PipelineController extends GetxController {
  PipelineController({
    required TelegramGateway service,
    required SettingsController settingsController,
    required OperationJournalRepository journalRepository,
  }) : _service = service,
       _settingsController = settingsController,
       _journalRepository = journalRepository;

  final TelegramGateway _service;
  final SettingsController _settingsController;
  final OperationJournalRepository _journalRepository;

  final currentMessage = Rxn<PipelineMessage>();
  final loading = false.obs;
  final processing = false.obs;
  final isOnline = false.obs;
  final logs = <ClassifyOperationLog>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;

  StreamSubscription<ConnectionState>? _connectionSub;
  ClassifyReceipt? _lastSuccessReceipt;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _connectionSub = _service.connectionStates.listen((state) {
      isOnline.value = state is ConnectionStateReady;
      if (state is ConnectionStateReady &&
          currentMessage.value == null &&
          !loading.value) {
        unawaited(fetchNext());
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    if (isOnline.value) {
      unawaited(fetchNext());
    }
  }

  Future<void> fetchNext() async {
    loading.value = true;
    try {
      currentMessage.value = await _service.fetchNextMessage(
        direction: _settingsController.settings.value.fetchDirection,
        sourceChatId: _settingsController.settings.value.sourceChatId,
      );
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    } catch (error) {
      _showGeneralError(error.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> skipCurrent() async {
    if (processing.value || !isOnline.value || currentMessage.value == null) {
      return;
    }
    final messageId = currentMessage.value!.id;
    await _appendLog(
      ClassifyOperationLog(
        id: _buildId('skip', messageId),
        categoryKey: '-',
        messageId: messageId,
        targetChatId: 0,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: ClassifyOperationStatus.skipped,
      ),
    );
    currentMessage.value = null;
    await fetchNext();
  }

  Future<void> runBatch(String key) async {
    if (processing.value || !isOnline.value) {
      return;
    }
    final maxCount = _settingsController.settings.value.batchSize;
    for (var i = 0; i < maxCount; i++) {
      if (currentMessage.value == null) {
        await fetchNext();
      }
      if (currentMessage.value == null) {
        break;
      }
      await classify(key);
      if (i + 1 < maxCount) {
        await _delayThrottle();
      }
    }
  }

  Future<bool> classify(String key) async {
    if (processing.value || !isOnline.value) {
      return false;
    }
    final message = currentMessage.value;
    if (message == null) {
      return false;
    }

    final target = _settingsController.getCategory(key);
    if (target.targetChatId == null) {
      Get.snackbar('未配置目标会话', '请先在设置里选择 ${target.name} 的目标会话');
      return false;
    }

    processing.value = true;
    try {
      final receipt = await _service.classifyMessage(
        sourceChatId: message.sourceChatId,
        messageId: message.id,
        targetChatId: target.targetChatId!,
      );
      _lastSuccessReceipt = receipt;
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('ok', message.id),
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId!,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.success,
        ),
      );
      currentMessage.value = null;
      await fetchNext();
      return true;
    } on TdlibFailure catch (error) {
      await _appendFailureAndRetry(
        error: error,
        key: key,
        message: message,
        targetChatId: target.targetChatId!,
      );
      _showTdlibError(error);
      return false;
    } finally {
      processing.value = false;
    }
  }

  Future<void> undoLastStep() async {
    if (processing.value || !isOnline.value) {
      return;
    }
    final receipt = _lastSuccessReceipt;
    if (receipt == null) {
      Get.snackbar('无法撤销', '当前没有可撤销的成功操作');
      return;
    }

    processing.value = true;
    try {
      await _service.undoClassify(
        sourceChatId: receipt.sourceChatId,
        targetChatId: receipt.targetChatId,
        targetMessageId: receipt.targetMessageId,
      );
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('undo_ok', receipt.sourceMessageId),
          categoryKey: '-',
          messageId: receipt.sourceMessageId,
          targetChatId: receipt.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.undoSuccess,
        ),
      );
      _lastSuccessReceipt = null;
      await fetchNext();
    } on TdlibFailure catch (error) {
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('undo_fail', receipt.sourceMessageId),
          categoryKey: '-',
          messageId: receipt.sourceMessageId,
          targetChatId: receipt.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.undoFailed,
          reason: error.toString(),
        ),
      );
      _showTdlibError(error);
    } finally {
      processing.value = false;
    }
  }

  Future<void> retryNextFailed() async {
    if (processing.value || !isOnline.value || retryQueue.isEmpty) {
      return;
    }
    processing.value = true;
    final item = retryQueue.first;
    try {
      await _service.classifyMessage(
        sourceChatId:
            item.sourceChatId ??
            _settingsController.settings.value.sourceChatId,
        messageId: item.messageId,
        targetChatId: item.targetChatId,
      );
      retryQueue.removeAt(0);
      await _journalRepository.saveRetryQueue(retryQueue);
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('retry_ok', item.messageId),
          categoryKey: item.categoryKey,
          messageId: item.messageId,
          targetChatId: item.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.retrySuccess,
        ),
      );
    } on TdlibFailure catch (error) {
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('retry_fail', item.messageId),
          categoryKey: item.categoryKey,
          messageId: item.messageId,
          targetChatId: item.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.retryFailed,
          reason: error.toString(),
        ),
      );
      retryQueue
        ..removeAt(0)
        ..add(item);
      await _journalRepository.saveRetryQueue(retryQueue);
      _showTdlibError(error);
    } finally {
      processing.value = false;
    }
  }

  Future<void> _appendFailureAndRetry({
    required TdlibFailure error,
    required String key,
    required PipelineMessage message,
    required int targetChatId,
  }) async {
    await _appendLog(
      ClassifyOperationLog(
        id: _buildId('fail', message.id),
        categoryKey: key,
        messageId: message.id,
        targetChatId: targetChatId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: ClassifyOperationStatus.failed,
        reason: error.toString(),
      ),
    );
    await _enqueueRetry(
      RetryQueueItem(
        id: _buildId('retry', message.id),
        categoryKey: key,
        sourceChatId: message.sourceChatId,
        messageId: message.id,
        targetChatId: targetChatId,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        reason: error.toString(),
      ),
    );
  }

  Future<void> _appendLog(ClassifyOperationLog log) async {
    logs.insert(0, log);
    await _journalRepository.saveLogs(logs);
  }

  Future<void> _enqueueRetry(RetryQueueItem item) async {
    retryQueue.add(item);
    await _journalRepository.saveRetryQueue(retryQueue);
  }

  Future<void> _delayThrottle() async {
    final delayMs = _settingsController.settings.value.throttleMs;
    if (delayMs <= 0) {
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  String _buildId(String prefix, int messageId) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$messageId-$now';
  }

  void _showTdlibError(TdlibFailure error) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，需等待 $waitSeconds 秒';
      Get.snackbar('操作过快', '触发 FloodWait$suffix');
      return;
    }
    if (kind == TdErrorKind.network) {
      Get.snackbar('网络异常', '请检查网络连接后重试');
      return;
    }
    if (kind == TdErrorKind.auth) {
      Get.snackbar('鉴权异常', '登录态可能失效，请重新登录');
      return;
    }
    if (kind == TdErrorKind.permission) {
      Get.snackbar('权限异常', '目标会话可能无发送权限');
      return;
    }
    Get.snackbar('TDLib 错误', error.toString());
  }

  void _showGeneralError(String message) {
    Get.snackbar('运行异常', message);
  }

  @override
  void onClose() {
    _connectionSub?.cancel();
    super.onClose();
  }
}
