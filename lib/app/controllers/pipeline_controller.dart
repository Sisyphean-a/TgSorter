import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class PipelineController extends GetxController {
  static const Duration _videoRefreshInterval = Duration(seconds: 1);
  static const int _messagePageSize = 20;

  PipelineController({
    required TelegramGateway service,
    required SettingsController settingsController,
    required OperationJournalRepository journalRepository,
    required AppErrorController errorController,
  }) : _service = service,
       _settingsController = settingsController,
       _journalRepository = journalRepository,
       _errorController = errorController;

  final TelegramGateway _service;
  final SettingsController _settingsController;
  final OperationJournalRepository _journalRepository;
  final AppErrorController _errorController;

  final currentMessage = Rxn<PipelineMessage>();
  final loading = false.obs;
  final processing = false.obs;
  final videoPreparing = false.obs;
  final isOnline = false.obs;
  final logs = <ClassifyOperationLog>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;
  final canShowPrevious = false.obs;
  final canShowNext = false.obs;

  StreamSubscription<TdConnectionState>? _connectionSub;
  StreamSubscription<TdAuthState>? _authSub;
  Timer? _videoRefreshTimer;
  ClassifyReceipt? _lastSuccessReceipt;
  bool _isAuthorized = false;
  final List<PipelineMessage> _messageCache = <PipelineMessage>[];
  int _currentIndex = -1;
  int? _tailMessageId;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _connectionSub = _service.connectionStates.listen((state) {
      isOnline.value = state.isReady;
      _tryAutoFetchNext();
    });
    _authSub = _service.authStates.listen((state) {
      _isAuthorized = state.isReady;
      _tryAutoFetchNext();
    });
  }

  @override
  void onReady() {
    super.onReady();
    _tryAutoFetchNext();
  }

  Future<void> fetchNext() async {
    _stopVideoRefresh();
    loading.value = true;
    try {
      await _loadInitialMessages();
      _refreshCurrentMediaIfNeeded();
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    } catch (error) {
      _showGeneralError(error.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> prepareCurrentVideo() async {
    final message = currentMessage.value;
    if (message == null ||
        (message.preview.kind != MessagePreviewKind.video &&
            message.preview.kind != MessagePreviewKind.audio) ||
        videoPreparing.value) {
      return;
    }
    videoPreparing.value = true;
    try {
      currentMessage.value = await _service.prepareVideoPlayback(
        sourceChatId: message.sourceChatId,
        messageId: message.id,
      );
      await _refreshCurrentMediaIfNeeded();
    } catch (error) {
      _showGeneralError(error.toString());
      videoPreparing.value = false;
    }
  }

  Future<void> skipCurrent() async {
    if (processing.value || currentMessage.value == null) {
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
    await showNextMessage();
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

    processing.value = true;
    try {
      final receipt = await _service.classifyMessage(
        sourceChatId: message.sourceChatId,
        messageId: message.id,
        targetChatId: target.targetChatId,
        asCopy: _settingsController.settings.value.forwardAsCopy,
      );
      _lastSuccessReceipt = receipt;
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('ok', message.id),
          categoryKey: key,
          messageId: message.id,
          targetChatId: target.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.success,
        ),
      );
      _removeCurrentMessage();
      await _ensureVisibleMessage();
      return true;
    } on TdlibFailure catch (error) {
      await _appendFailureAndRetry(
        error: error,
        key: key,
        message: message,
        targetChatId: target.targetChatId,
      );
      _showTdlibError(error);
      return false;
    } finally {
      processing.value = false;
    }
  }

  Future<void> showPreviousMessage() async {
    if (processing.value || _currentIndex <= 0) {
      return;
    }
    _stopVideoRefresh();
    _currentIndex--;
    _syncCurrentMessage();
  }

  Future<void> showNextMessage() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    _stopVideoRefresh();
    if (_currentIndex + 1 < _messageCache.length) {
      _currentIndex++;
      _syncCurrentMessage();
      await _prefetchIfNeeded();
      return;
    }
    await _appendMoreMessages();
    if (_currentIndex + 1 < _messageCache.length) {
      _currentIndex++;
      _syncCurrentMessage();
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
        asCopy: _settingsController.settings.value.forwardAsCopy,
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
      _reportError('操作过快', '触发 FloodWait$suffix');
      return;
    }
    if (kind == TdErrorKind.network) {
      _reportError('网络异常', '请检查网络连接后重试');
      return;
    }
    if (kind == TdErrorKind.auth) {
      _reportError('鉴权异常', '登录态可能失效，请重新登录');
      return;
    }
    if (kind == TdErrorKind.permission) {
      _reportError('权限异常', '目标会话可能无发送权限');
      return;
    }
    _reportError('TDLib 错误', error.toString());
  }

  void _showGeneralError(String message) {
    _reportError('运行异常', message);
  }

  void _tryAutoFetchNext() {
    if (!_isAuthorized ||
        !isOnline.value ||
        currentMessage.value != null ||
        loading.value) {
      return;
    }
    unawaited(fetchNext());
  }

  Future<void> _refreshCurrentMediaIfNeeded() async {
    final message = currentMessage.value;
    if (message == null || !_needsMediaRefresh(message.preview)) {
      videoPreparing.value = false;
      return;
    }
    _syncPreparingState(message.preview);
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = Timer.periodic(_videoRefreshInterval, (_) async {
      final current = currentMessage.value;
      if (current == null || !_needsMediaRefresh(current.preview)) {
        _stopVideoRefresh();
        return;
      }
      final refreshed = await _service.refreshMessage(
        sourceChatId: current.sourceChatId,
        messageId: current.id,
      );
      currentMessage.value = refreshed;
      _syncPreparingState(refreshed.preview);
      if (!_needsMediaRefresh(refreshed.preview)) {
        _stopVideoRefresh();
      }
    });
  }

  bool _needsMediaRefresh(MessagePreview preview) {
    if (preview.kind == MessagePreviewKind.video) {
      return preview.localVideoThumbnailPath == null ||
          (videoPreparing.value && preview.localVideoPath == null);
    }
    if (preview.kind == MessagePreviewKind.audio) {
      return videoPreparing.value && preview.localAudioPath == null;
    }
    return false;
  }

  void _syncPreparingState(MessagePreview preview) {
    if (preview.kind == MessagePreviewKind.video) {
      videoPreparing.value = preview.localVideoPath == null && videoPreparing.value;
      return;
    }
    if (preview.kind == MessagePreviewKind.audio) {
      videoPreparing.value = preview.localAudioPath == null && videoPreparing.value;
      return;
    }
    videoPreparing.value = false;
  }

  Future<void> _loadInitialMessages() async {
    _messageCache.clear();
    _currentIndex = -1;
    _tailMessageId = null;
    final page = await _service.fetchMessagePage(
      direction: _settingsController.settings.value.fetchDirection,
      sourceChatId: _settingsController.settings.value.sourceChatId,
      fromMessageId: null,
      limit: _messagePageSize,
    );
    _messageCache.addAll(page);
    _tailMessageId = page.isEmpty ? null : page.last.id;
    if (_messageCache.isEmpty) {
      currentMessage.value = null;
      _syncNavigationState();
      return;
    }
    _currentIndex = 0;
    _syncCurrentMessage();
    await _prefetchIfNeeded();
  }

  Future<void> _appendMoreMessages() async {
    if (!isOnline.value || _tailMessageId == null) {
      return;
    }
    final page = await _service.fetchMessagePage(
      direction: _settingsController.settings.value.fetchDirection,
      sourceChatId: _settingsController.settings.value.sourceChatId,
      fromMessageId: _tailMessageId,
      limit: _messagePageSize,
    );
    if (page.isEmpty) {
      return;
    }
    final knownIds = _messageCache.map((item) => item.id).toSet();
    for (final item in page) {
      if (knownIds.add(item.id)) {
        _messageCache.add(item);
      }
    }
    _tailMessageId = _messageCache.last.id;
    _syncNavigationState();
  }

  Future<void> _prefetchIfNeeded() async {
    final remaining = _messageCache.length - _currentIndex - 1;
    if (remaining > 2) {
      return;
    }
    await _appendMoreMessages();
  }

  void _removeCurrentMessage() {
    if (_currentIndex < 0 || _currentIndex >= _messageCache.length) {
      return;
    }
    _messageCache.removeAt(_currentIndex);
    if (_currentIndex >= _messageCache.length) {
      _currentIndex = _messageCache.length - 1;
    }
  }

  Future<void> _ensureVisibleMessage() async {
    if (_messageCache.isEmpty) {
      await _appendMoreMessages();
    }
    if (_messageCache.isEmpty) {
      currentMessage.value = null;
      _currentIndex = -1;
      _syncNavigationState();
      return;
    }
    if (_currentIndex < 0) {
      _currentIndex = 0;
    }
    _syncCurrentMessage();
    await _prefetchIfNeeded();
  }

  void _syncCurrentMessage() {
    if (_currentIndex < 0 || _currentIndex >= _messageCache.length) {
      currentMessage.value = null;
      _syncNavigationState();
      return;
    }
    currentMessage.value = _messageCache[_currentIndex];
    _syncNavigationState();
  }

  void _syncNavigationState() {
    canShowPrevious.value = _currentIndex > 0;
    canShowNext.value = _currentIndex >= 0 && _currentIndex < _messageCache.length - 1;
  }

  void _stopVideoRefresh() {
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = null;
    videoPreparing.value = false;
  }

  void _reportError(String title, String message) {
    _errorController.report(title: title, message: message);
  }

  @override
  void onClose() {
    _stopVideoRefresh();
    _connectionSub?.cancel();
    _authSub?.cancel();
    super.onClose();
  }
}
