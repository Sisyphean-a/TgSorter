import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/features/pipeline/application/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_action_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_refresh_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_provider.dart';
import 'package:tgsorter/app/features/pipeline/application/recovery_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
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
    PipelineRuntimeState? runtimeState,
    PipelineNavigationService? navigation,
    PipelineActionService? actions,
    PipelineRecoveryService? recovery,
    PipelineMediaRefreshService? mediaRefresh,
    RemainingCountService? remainingCountService,
    PipelineCoordinator? coordinator,
  }) : _service = service,
       _settingsProvider = settingsProvider,
       _journalRepository = journalRepository,
       _errorController = errorController,
       _runtimeState = runtimeState ?? PipelineRuntimeState() {
    final resolvedNavigation =
        navigation ?? PipelineNavigationService(state: _runtimeState);
    final resolvedActions =
        actions ??
        PipelineActionService(
          state: _runtimeState,
          navigation: resolvedNavigation,
          classifyGateway: _TelegramClassifyGateway(service),
          settings: settingsProvider,
          journalRepository: journalRepository,
          logs: logs,
          retryQueue: retryQueue,
        );
    final resolvedRecovery =
        recovery ??
        PipelineRecoveryService(
          recoveryGateway: service is RecoverableClassifyGateway
              ? _TelegramRecoveryGateway(service as RecoverableClassifyGateway)
              : null,
          errors: errorController,
        );
    final resolvedMediaRefresh =
        mediaRefresh ??
        PipelineMediaRefreshService(
          mediaGateway: _TelegramMediaGateway(service),
          messageGateway: _TelegramMessageReadGateway(service),
        );
    final resolvedRemainingCount =
        remainingCountService ?? RemainingCountService();
    _coordinator =
        coordinator ??
        PipelineCoordinator(
          runtimeState: _runtimeState,
          navigation: resolvedNavigation,
          actions: resolvedActions,
          recovery: resolvedRecovery,
          mediaRefresh: resolvedMediaRefresh,
          remainingCount: resolvedRemainingCount,
        );
  }

  final TelegramGateway _service;
  final PipelineSettingsProvider _settingsProvider;
  final OperationJournalRepository _journalRepository;
  final AppErrorController _errorController;
  final PipelineRuntimeState _runtimeState;
  late final PipelineCoordinator _coordinator;

  Rxn<PipelineMessage> get currentMessage => _runtimeState.currentMessage;
  RxBool get loading => _runtimeState.loading;
  RxBool get processing => _runtimeState.processing;
  RxBool get videoPreparing => _runtimeState.videoPreparing;
  RxBool get isOnline => _runtimeState.isOnline;
  final logs = <ClassifyOperationLog>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;
  RxBool get canShowPrevious => _runtimeState.canShowPrevious;
  RxBool get canShowNext => _runtimeState.canShowNext;
  RxnInt get remainingCount => _runtimeState.remainingCount;
  RxBool get remainingCountLoading => _runtimeState.remainingCountLoading;

  StreamSubscription<TdConnectionState>? _connectionSub;
  StreamSubscription<TdAuthState>? _authSub;
  Worker? _settingsWorker;
  Timer? _videoRefreshTimer;
  ClassifyReceipt? _lastSuccessReceipt;
  bool _isAuthorized = false;
  int? _tailMessageId;
  int? _refreshTargetMessageId;
  MessageFetchDirection? _lastFetchDirection;
  int? _lastSourceChatId;
  final Set<int> _previewPreparedMessageIds = <int>{};

  List<PipelineMessage> get _messageCache => _runtimeState.cache;
  int get _currentIndex => _runtimeState.currentIndex;
  PipelineNavigationService get _navigation => _coordinator.navigation;

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
      await _refreshCurrentMediaIfNeeded();
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
      final prepared = await _coordinator.prepareCurrentMedia(
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
    final skipped = await _coordinator.actions.skipCurrent(
      source: source,
      idBuilder: _buildId,
      nowMs: _nowMs,
    );
    if (!skipped) {
      return;
    }
    await _ensureVisibleMessage();
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
    try {
      final ok = await _coordinator.classify(key);
      final receipt = _coordinator.actions.lastReceipt;
      if (!ok || receipt == null) {
        return false;
      }
      _lastSuccessReceipt = receipt;
      _decrementRemainingCount(receipt.sourceMessageIds.length);
      await _ensureVisibleMessage();
      return true;
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
      return false;
    }
  }

  Future<void> showPreviousMessage() async {
    if (processing.value || _currentIndex <= 0) {
      return;
    }
    _stopVideoRefresh();
    await _navigation.showPrevious();
    await _refreshCurrentMediaIfNeeded();
    await _prefetchIfNeeded();
  }

  Future<void> showNextMessage() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    _stopVideoRefresh();
    if (_currentIndex + 1 < _messageCache.length) {
      await _navigation.showNext();
      await _refreshCurrentMediaIfNeeded();
      await _prefetchIfNeeded();
      return;
    }
    await _appendMoreMessages();
    if (_currentIndex + 1 < _messageCache.length) {
      await _navigation.showNext();
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
    try {
      final undone = await _coordinator.actions.undoLastSuccess(
        receipt: receipt,
        idBuilder: _buildId,
        nowMs: _nowMs,
      );
      if (!undone) {
        return;
      }
      _lastSuccessReceipt = null;
      _incrementRemainingCount(receipt.sourceMessageIds.length);
      await fetchNext();
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    }
  }

  Future<void> retryNextFailed() async {
    if (processing.value || !isOnline.value || retryQueue.isEmpty) {
      return;
    }
    try {
      await _coordinator.actions.retryNextFailed(
        idBuilder: _buildId,
        nowMs: _nowMs,
      );
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    }
  }

  Future<void> _delayThrottle() async {
    final delayMs = _settingsProvider.currentSettings.throttleMs;
    if (delayMs <= 0) {
      return;
    }
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  String _buildId(String prefix, int messageId) {
    return '$prefix-$messageId-${DateTime.now().microsecondsSinceEpoch}';
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

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
    if (!_coordinator.recovery.isCompleted) {
      _triggerTransactionRecoveryIfNeeded();
      return;
    }
    if (currentMessage.value != null) {
      return;
    }
    unawaited(fetchNext());
  }

  void _triggerTransactionRecoveryIfNeeded() {
    if (_coordinator.recovery.isRunning || _coordinator.recovery.isCompleted) {
      return;
    }
    unawaited(_recoverPendingTransactions());
  }

  Future<void> _recoverPendingTransactions() async {
    await _coordinator.recoverPendingTransactionsIfNeeded();
    if (_coordinator.recovery.isCompleted) {
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
    _coordinator.remainingCount.beginRequest();
    _coordinator.navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    _tailMessageId = null;
    remainingCount.value = null;
    remainingCountLoading.value = false;
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
      final refreshed = await _coordinator.mediaRefresh.refreshCurrentMedia(
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
    _navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    _tailMessageId = null;
    final page = await _service.fetchMessagePage(
      direction: _settingsProvider.currentSettings.fetchDirection,
      sourceChatId: _settingsProvider.currentSettings.sourceChatId,
      fromMessageId: null,
      limit: _messagePageSize,
    );
    _navigation.replaceMessages(page);
    _tailMessageId = page.isEmpty ? null : page.last.id;
    if (page.isEmpty) {
      return;
    }
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
    _navigation.appendUniqueMessages(page);
    _tailMessageId = _messageCache.last.id;
  }

  Future<void> _prefetchIfNeeded() async {
    if (_shouldAppendMoreMessages()) {
      await _appendMoreMessages();
    }
    await _prepareUpcomingPreviews();
  }

  Future<void> _ensureVisibleMessage() async {
    if (_navigation.isEmpty) {
      await _appendMoreMessages();
    }
    _navigation.ensureCurrentAndSync();
    if (_navigation.isEmpty) {
      return;
    }
    await _refreshCurrentMediaIfNeeded();
    await _prefetchIfNeeded();
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
    await _coordinator.remainingCount.refreshRemainingCount(
      loadCount: () => _service.countRemainingMessages(
        sourceChatId: _settingsProvider.currentSettings.sourceChatId,
      ),
      onStart: () {
        remainingCountLoading.value = true;
      },
      onSuccess: (nextCount) {
        remainingCount.value = nextCount;
      },
      onError: (error) {
        remainingCount.value = null;
        _showGeneralError('剩余统计失败：$error');
      },
      onComplete: () {
        remainingCountLoading.value = false;
      },
    );
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

class _TelegramClassifyGateway implements ClassifyGateway {
  const _TelegramClassifyGateway(this._service);

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

class _TelegramMediaGateway implements MediaGateway {
  const _TelegramMediaGateway(this._service);

  final TelegramGateway _service;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) {
    return _service.prepareMediaPreview(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    return _service.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}

class _TelegramMessageReadGateway implements MessageReadGateway {
  const _TelegramMessageReadGateway(this._service);

  final TelegramGateway _service;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    return _service.countRemainingMessages(sourceChatId: sourceChatId);
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) {
    return _service.fetchMessagePage(
      direction: direction,
      sourceChatId: sourceChatId,
      fromMessageId: fromMessageId,
      limit: limit,
    );
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) {
    return _service.fetchNextMessage(
      direction: direction,
      sourceChatId: sourceChatId,
    );
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    return _service.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}

class _TelegramRecoveryGateway implements RecoveryGateway {
  const _TelegramRecoveryGateway(this._service);

  final RecoverableClassifyGateway _service;

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    return _service.recoverPendingClassifyOperations();
  }
}
