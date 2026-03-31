import 'dart:async';

import 'package:get/get.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

class PipelineController extends GetxController {
  PipelineController({
    required TelegramService service,
    required SettingsController settingsController,
    required OperationJournalRepository journalRepository,
  }) : _service = service,
       _settingsController = settingsController,
       _journalRepository = journalRepository;

  final TelegramService _service;
  final SettingsController _settingsController;
  final OperationJournalRepository _journalRepository;

  final currentMessage = Rxn<PipelineMessage>();
  final loading = false.obs;
  final processing = false.obs;
  final isOnline = false.obs;
  final logs = <ClassifyOperationLog>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;

  StreamSubscription<ConnectionState>? _connectionSub;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _connectionSub = _service.connectionStates.listen((state) {
      isOnline.value = state is ConnectionStateReady;
    });
  }

  @override
  void onReady() {
    super.onReady();
    fetchNext();
  }

  Future<void> fetchNext() async {
    loading.value = true;
    try {
      currentMessage.value = await _service.fetchNextSavedMessage(
        direction: _settingsController.settings.value.fetchDirection,
      );
    } on TdlibRequestException catch (error) {
      _showTdlibError(error);
    } finally {
      loading.value = false;
    }
  }

  Future<void> classify(String key) async {
    if (processing.value || !isOnline.value) {
      return;
    }
    final message = currentMessage.value;
    if (message == null) {
      return;
    }

    final target = _settingsController.getCategory(key);
    if (target.targetChatId == null) {
      Get.snackbar('未配置目标会话', '请先在设置里填写 ${target.name} 的 Chat ID');
      return;
    }

    processing.value = true;
    try {
      await _service.classifyMessage(
        messageId: message.id,
        targetChatId: target.targetChatId!,
      );
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
    } on TdlibRequestException catch (error) {
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('fail', message.id),
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId!,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.failed,
          reason: error.toString(),
        ),
      );
      await _enqueueRetry(
        RetryQueueItem(
          id: _buildId('retry', message.id),
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId!,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
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
    } on TdlibRequestException catch (error) {
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

  Future<void> _appendLog(ClassifyOperationLog log) async {
    logs.insert(0, log);
    await _journalRepository.saveLogs(logs);
  }

  Future<void> _enqueueRetry(RetryQueueItem item) async {
    retryQueue.add(item);
    await _journalRepository.saveRetryQueue(retryQueue);
  }

  String _buildId(String prefix, int messageId) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$messageId-$now';
  }

  void _showTdlibError(TdlibRequestException error) {
    if (error.code == 420) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，需等待 $waitSeconds 秒';
      Get.snackbar('操作过快', '触发 FloodWait$suffix');
      return;
    }
    Get.snackbar('TDLib 错误', error.toString());
  }

  @override
  void onClose() {
    _connectionSub?.cancel();
    super.onClose();
  }
}
