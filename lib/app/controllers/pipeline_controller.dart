import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_settings_provider.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/models/app_settings.dart';
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
    required PipelineSettingsProvider settingsProvider,
    required OperationJournalRepository journalRepository,
    required AppErrorController errorController,
  }) : _service = service,
       _settingsProvider = settingsProvider,
       _journalRepository = journalRepository,
       _errorController = errorController;

  final TelegramGateway _service;
  final PipelineSettingsProvider _settingsProvider;
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
  final remainingCount = RxnInt();
  final remainingCountLoading = false.obs;

  StreamSubscription<TdConnectionState>? _connectionSub;
  StreamSubscription<TdAuthState>? _authSub;
  Worker? _settingsWorker;
  Timer? _videoRefreshTimer;
  ClassifyReceipt? _lastSuccessReceipt;
  bool _isAuthorized = false;
  final List<PipelineMessage> _messageCache = <PipelineMessage>[];
  int _currentIndex = -1;
  int? _tailMessageId;
  int? _refreshTargetMessageId;
  MessageFetchDirection? _lastFetchDirection;
  int? _lastSourceChatId;
  int _remainingCountRequestId = 0;
  final Set<int> _previewPreparedMessageIds = <int>{};
  bool _recoveryCompleted = false;
  bool _recoveringTransactions = false;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _lastFetchDirection = _settingsProvider.currentSettings.fetchDirection;
    _lastSourceChatId = _settingsProvider.currentSettings.sourceChatId;
    _connectionSub = _service.connectionStates.listen((state) {
      isOnline.value = state.isReady;
      _tryAutoFetchNext();
    });
    _authSub = _service.authStates.listen((state) {
      _isAuthorized = state.isReady;
      _tryAutoFetchNext();
    });
    _settingsWorker = ever<AppSettings>(
      _settingsProvider.settingsStream,
      _handleSettingsChanged,
    );
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

  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    final message = currentMessage.value;
    if (message == null ||
        (message.preview.kind != MessagePreviewKind.video &&
            message.preview.kind != MessagePreviewKind.audio) ||
        videoPreparing.value) {
      return;
    }
    final requestedMessageId = targetMessageId ?? message.id;
    _refreshTargetMessageId = requestedMessageId;
    videoPreparing.value = true;
    try {
      final prepared = await _service.prepareMediaPlayback(
        sourceChatId: message.sourceChatId,
        messageId: requestedMessageId,
      );
      currentMessage.value = _mergePreparedMessage(message, prepared);
      await _refreshCurrentMediaIfNeeded();
    } catch (error) {
      _showGeneralError(error.toString());
      videoPreparing.value = false;
    }
  }

  Future<void> skipCurrent([String source = 'unknown']) async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    final message = currentMessage.value!;
    developer.log(
      'skipCurrent source=$source messageIds=${message.messageIds.join(",")}',
      name: 'PipelineController',
      stackTrace: StackTrace.current,
    );
    final messageId = message.id;
    await _appendLog(
      ClassifyOperationLog(
        id: _buildId('skip', messageId),
        categoryKey: '-',
        messageId: messageId,
        targetChatId: 0,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        status: ClassifyOperationStatus.skipped,
        reason: source,
      ),
    );
    await showNextMessage();
  }

  Future<void> runBatch(String key) async {
    if (processing.value || !isOnline.value) {
      return;
    }
    final maxCount = _settingsProvider.currentSettings.batchSize;
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

    final target = _settingsProvider.getCategory(key);

    processing.value = true;
    try {
      final receipt = await _service.classifyMessage(
        sourceChatId: message.sourceChatId,
        messageIds: message.messageIds,
        targetChatId: target.targetChatId,
        asCopy: _settingsProvider.currentSettings.forwardAsCopy,
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
      _decrementRemainingCount(message.messageIds.length);
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
    await _refreshCurrentMediaIfNeeded();
    await _prefetchIfNeeded();
  }

  Future<void> showNextMessage() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    _stopVideoRefresh();
    if (_currentIndex + 1 < _messageCache.length) {
      _currentIndex++;
      _syncCurrentMessage();
      await _refreshCurrentMediaIfNeeded();
      await _prefetchIfNeeded();
      return;
    }
    await _appendMoreMessages();
    if (_currentIndex + 1 < _messageCache.length) {
      _currentIndex++;
      _syncCurrentMessage();
      await _refreshCurrentMediaIfNeeded();
      await _prefetchIfNeeded();
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
        targetMessageIds: receipt.targetMessageIds,
      );
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('undo_ok', receipt.primarySourceMessageId),
          categoryKey: '-',
          messageId: receipt.primarySourceMessageId,
          targetChatId: receipt.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.undoSuccess,
        ),
      );
      _lastSuccessReceipt = null;
      _incrementRemainingCount(receipt.sourceMessageIds.length);
      await fetchNext();
    } on TdlibFailure catch (error) {
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('undo_fail', receipt.primarySourceMessageId),
          categoryKey: '-',
          messageId: receipt.primarySourceMessageId,
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
            item.sourceChatId ?? _settingsProvider.currentSettings.sourceChatId,
        messageIds: item.messageIds,
        targetChatId: item.targetChatId,
        asCopy: _settingsProvider.currentSettings.forwardAsCopy,
      );
      retryQueue.removeAt(0);
      await _journalRepository.saveRetryQueue(retryQueue);
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('retry_ok', item.primaryMessageId),
          categoryKey: item.categoryKey,
          messageId: item.primaryMessageId,
          targetChatId: item.targetChatId,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
          status: ClassifyOperationStatus.retrySuccess,
        ),
      );
    } on TdlibFailure catch (error) {
      await _appendLog(
        ClassifyOperationLog(
          id: _buildId('retry_fail', item.primaryMessageId),
          categoryKey: item.categoryKey,
          messageId: item.primaryMessageId,
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
        messageIds: message.messageIds,
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
    final delayMs = _settingsProvider.currentSettings.throttleMs;
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
    if (!_isAuthorized || !isOnline.value || loading.value) {
      return;
    }
    if (!_recoveryCompleted) {
      _triggerTransactionRecoveryIfNeeded();
      return;
    }
    if (currentMessage.value != null) {
      return;
    }
    unawaited(fetchNext());
  }

  void _triggerTransactionRecoveryIfNeeded() {
    if (_recoveringTransactions || _recoveryCompleted) {
      return;
    }
    final recoverable = _service;
    if (recoverable is! RecoverableClassifyGateway) {
      _recoveryCompleted = true;
      _tryAutoFetchNext();
      return;
    }
    _recoveringTransactions = true;
    unawaited(
      _recoverPendingTransactions(recoverable as RecoverableClassifyGateway),
    );
  }

  Future<void> _recoverPendingTransactions(
    RecoverableClassifyGateway recoverable,
  ) async {
    try {
      final summary = await recoverable.recoverPendingClassifyOperations();
      if (summary.failedCount > 0 || summary.manualReviewCount > 0) {
        _reportError(
          '分类事务恢复提醒',
          '自动恢复 ${summary.recoveredCount} 条，'
              '仍有 ${summary.manualReviewCount} 条需要人工核查，'
              '${summary.failedCount} 条恢复失败',
        );
      }
    } catch (error) {
      _reportError('分类事务恢复失败', '$error');
    } finally {
      _recoveringTransactions = false;
      _recoveryCompleted = true;
      _tryAutoFetchNext();
    }
  }

  void _handleSettingsChanged(AppSettings settings) {
    final directionChanged = settings.fetchDirection != _lastFetchDirection;
    final sourceChanged = settings.sourceChatId != _lastSourceChatId;
    _lastFetchDirection = settings.fetchDirection;
    _lastSourceChatId = settings.sourceChatId;
    if (!directionChanged && !sourceChanged) {
      return;
    }
    _resetPipelineState();
    _tryAutoFetchNext();
  }

  void _resetPipelineState() {
    _stopVideoRefresh();
    _remainingCountRequestId++;
    _messageCache.clear();
    _previewPreparedMessageIds.clear();
    _currentIndex = -1;
    _tailMessageId = null;
    currentMessage.value = null;
    remainingCount.value = null;
    remainingCountLoading.value = false;
    _syncNavigationState();
  }

  Future<void> _refreshCurrentMediaIfNeeded() async {
    final message = currentMessage.value;
    if (message == null || !_needsMediaRefresh(message.preview)) {
      videoPreparing.value = false;
      _refreshTargetMessageId = null;
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
      final refreshMessageId = _refreshTargetMessageId ?? current.id;
      final refreshed = await _service.refreshMessage(
        sourceChatId: current.sourceChatId,
        messageId: refreshMessageId,
      );
      final merged = _mergePreparedMessage(current, refreshed);
      currentMessage.value = merged;
      _syncPreparingState(merged.preview);
      if (!_needsMediaRefresh(merged.preview)) {
        _stopVideoRefresh();
      }
    });
  }

  bool _needsMediaRefresh(MessagePreview preview) {
    if (preview.kind == MessagePreviewKind.video) {
      if (preview.mediaItems.isNotEmpty) {
        return preview.mediaItems.any((item) {
          if (item.kind != MediaItemKind.video) {
            return item.previewPath == null;
          }
          final waitingForPlayback =
              videoPreparing.value &&
              (_refreshTargetMessageId == null ||
                  _refreshTargetMessageId == item.messageId);
          return item.previewPath == null ||
              (waitingForPlayback && item.fullPath == null);
        });
      }
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
      if (preview.mediaItems.isNotEmpty) {
        final targetId = _refreshTargetMessageId;
        final waiting = preview.mediaItems.any((item) {
          if (item.kind != MediaItemKind.video) {
            return false;
          }
          if (targetId != null && item.messageId != targetId) {
            return false;
          }
          return item.fullPath == null;
        });
        videoPreparing.value = waiting && videoPreparing.value;
        return;
      }
      videoPreparing.value =
          preview.localVideoPath == null && videoPreparing.value;
      return;
    }
    if (preview.kind == MessagePreviewKind.audio) {
      videoPreparing.value =
          preview.localAudioPath == null && videoPreparing.value;
      return;
    }
    videoPreparing.value = false;
  }

  Future<void> _loadInitialMessages() async {
    unawaited(_refreshRemainingCount());
    _messageCache.clear();
    _previewPreparedMessageIds.clear();
    _currentIndex = -1;
    _tailMessageId = null;
    final page = await _service.fetchMessagePage(
      direction: _settingsProvider.currentSettings.fetchDirection,
      sourceChatId: _settingsProvider.currentSettings.sourceChatId,
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
    await _prepareUpcomingPreviews();
  }

  Future<void> _appendMoreMessages() async {
    if (!isOnline.value || _tailMessageId == null) {
      return;
    }
    final page = await _service.fetchMessagePage(
      direction: _settingsProvider.currentSettings.fetchDirection,
      sourceChatId: _settingsProvider.currentSettings.sourceChatId,
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
    if (_shouldAppendMoreMessages()) {
      await _appendMoreMessages();
    }
    await _prepareUpcomingPreviews();
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
    await _refreshCurrentMediaIfNeeded();
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
    canShowNext.value =
        _currentIndex >= 0 && _currentIndex < _messageCache.length - 1;
  }

  PipelineMessage _mergePreparedMessage(
    PipelineMessage current,
    PipelineMessage prepared,
  ) {
    if (current.preview.mediaItems.isNotEmpty) {
      final preparedItem = prepared.preview.mediaItems.isEmpty
          ? null
          : prepared.preview.mediaItems.first;
      if (preparedItem != null) {
        final items = current.preview.mediaItems
            .map((item) {
              if (item.messageId != prepared.id) {
                return item;
              }
              return item.copyWith(
                previewPath: preparedItem.previewPath,
                fullPath: preparedItem.fullPath,
                durationSeconds: preparedItem.durationSeconds,
                caption: preparedItem.caption,
              );
            })
            .toList(growable: false);
        final preview = current.preview.copyWith(
          mediaItems: items,
          localVideoPath: prepared.preview.localVideoPath,
          localVideoThumbnailPath: prepared.preview.localVideoThumbnailPath,
          localImagePath: prepared.preview.localImagePath,
        );
        return current.copyWith(preview: preview);
      }
    }
    if (current.preview.kind != MessagePreviewKind.audio ||
        current.preview.audioTracks.length <= 1) {
      return prepared;
    }
    final tracks = current.preview.audioTracks
        .map((track) {
          if (track.messageId != prepared.id) {
            return track;
          }
          final preview = prepared.preview;
          return track.copyWith(
            localAudioPath: preview.localAudioPath,
            audioDurationSeconds: preview.audioDurationSeconds,
            title: preview.title,
            subtitle: preview.subtitle,
          );
        })
        .toList(growable: false);
    return current.copyWith(
      preview: current.preview.copyWith(audioTracks: tracks),
    );
  }

  void _stopVideoRefresh() {
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = null;
    _refreshTargetMessageId = null;
    videoPreparing.value = false;
  }

  Future<void> _refreshRemainingCount() async {
    final requestId = ++_remainingCountRequestId;
    remainingCountLoading.value = true;
    try {
      final nextCount = await _service.countRemainingMessages(
        sourceChatId: _settingsProvider.currentSettings.sourceChatId,
      );
      if (requestId != _remainingCountRequestId) {
        return;
      }
      remainingCount.value = nextCount;
    } catch (error) {
      if (requestId != _remainingCountRequestId) {
        return;
      }
      remainingCount.value = null;
      _showGeneralError('剩余统计失败：$error');
    } finally {
      if (requestId == _remainingCountRequestId) {
        remainingCountLoading.value = false;
      }
    }
  }

  bool _shouldAppendMoreMessages() {
    final remaining = _messageCache.length - _currentIndex - 1;
    return remaining <= 2;
  }

  Future<void> _prepareUpcomingPreviews() async {
    final prefetchCount =
        _settingsProvider.currentSettings.previewPrefetchCount;
    if (prefetchCount <= 0 || _currentIndex < 0) {
      return;
    }
    final start = _currentIndex + 1;
    final end = math.min(_messageCache.length, start + prefetchCount);
    for (var index = start; index < end; index++) {
      final item = _messageCache[index];
      for (final messageId in item.messageIds) {
        if (!_previewPreparedMessageIds.add(messageId)) {
          continue;
        }
        await _service.prepareMediaPreview(
          sourceChatId: item.sourceChatId,
          messageId: messageId,
        );
      }
    }
  }

  void _decrementRemainingCount(int delta) {
    final current = remainingCount.value;
    if (current == null || current <= 0 || delta <= 0) {
      return;
    }
    remainingCount.value = math.max(0, current - delta);
  }

  void _incrementRemainingCount(int delta) {
    final current = remainingCount.value;
    if (current == null || delta <= 0) {
      return;
    }
    remainingCount.value = current + delta;
  }

  void _reportError(String title, String message) {
    _errorController.report(title: title, message: message);
  }

  @override
  void onClose() {
    _stopVideoRefresh();
    _connectionSub?.cancel();
    _authSub?.cancel();
    _settingsWorker?.dispose();
    super.onClose();
  }
}
