import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

import 'media_gateway.dart';
import 'message_read_gateway.dart';
import 'pipeline_action_service.dart';
import 'pipeline_error_mapper.dart';
import 'pipeline_gateway_adapters.dart';
import 'pipeline_media_controller.dart';
import 'pipeline_media_refresh_service.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_recovery_service.dart';
import 'pipeline_runtime_state.dart';
import 'pipeline_settings_reader.dart';
import 'remaining_count_service.dart';

class PipelineCoordinator extends GetxController {
  static const Duration _videoRefreshInterval = Duration(seconds: 1);
  static const int _messagePageSize = 20;

  PipelineCoordinator({
    required TelegramGateway service,
    required PipelineSettingsReader settingsReader,
    required OperationJournalRepository journalRepository,
    required AppErrorController errorController,
    PipelineRuntimeState? runtimeState,
    PipelineNavigationService? navigation,
    PipelineActionService? actions,
    PipelineRecoveryService? recovery,
    PipelineMediaRefreshService? mediaRefresh,
    RemainingCountService? remainingCountService,
  }) : _service = service,
       _settingsReader = settingsReader,
       _journalRepository = journalRepository,
       _errorController = errorController,
       _errorMapper = const PipelineErrorMapper(),
       runtimeState = runtimeState ?? PipelineRuntimeState() {
    _messageReadGateway = TelegramMessageReadGatewayAdapter(service);
    _mediaGateway = TelegramMediaGatewayAdapter(service);
    final resolvedNavigation =
        navigation ?? PipelineNavigationService(state: this.runtimeState);
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
    final resolvedMediaRefresh =
        mediaRefresh ??
        PipelineMediaRefreshService(
          mediaGateway: _mediaGateway,
          messageGateway: _messageReadGateway,
        );
    this.navigation = resolvedNavigation;
    this.actions = resolvedActions;
    this.recovery = resolvedRecovery;
    this.mediaRefresh = resolvedMediaRefresh;
    mediaController = PipelineMediaController(
      state: this.runtimeState,
      mediaRefresh: resolvedMediaRefresh,
      reportGeneralError: _showGeneralError,
      videoRefreshInterval: _videoRefreshInterval,
    );
    _remainingCountService = remainingCountService ?? RemainingCountService();
  }

  final TelegramGateway _service;
  final PipelineSettingsReader _settingsReader;
  final OperationJournalRepository _journalRepository;
  final AppErrorController _errorController;
  final PipelineErrorMapper _errorMapper;
  final PipelineRuntimeState runtimeState;
  late final MessageReadGateway _messageReadGateway;
  late final MediaGateway _mediaGateway;
  late final PipelineNavigationService navigation;
  late final PipelineActionService actions;
  late final PipelineRecoveryService recovery;
  late final PipelineMediaRefreshService mediaRefresh;
  late final PipelineMediaController mediaController;
  late final RemainingCountService _remainingCountService;

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get loading => runtimeState.loading;
  RxBool get processing => runtimeState.processing;
  RxBool get videoPreparing => runtimeState.videoPreparing;
  RxBool get isOnline => runtimeState.isOnline;
  final logs = <ClassifyOperationLog>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
  RxBool get remainingCountLoading => runtimeState.remainingCountLoading;
  RxnInt get remainingCount => runtimeState.remainingCount;

  StreamSubscription<TdConnectionState>? _connectionSub;
  StreamSubscription<TdAuthState>? _authSub;
  Worker? _settingsWorker;
  ClassifyReceipt? _lastSuccessReceipt;
  bool _isAuthorized = false;
  int? _tailMessageId;
  MessageFetchDirection? _lastFetchDirection;
  int? _lastSourceChatId;
  final Set<int> _previewPreparedMessageIds = <int>{};

  List<PipelineMessage> get _messageCache => runtimeState.cache;
  int get _currentIndex => runtimeState.currentIndex;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _lastFetchDirection = _settingsReader.currentSettings.fetchDirection;
    _lastSourceChatId = _settingsReader.currentSettings.sourceChatId;
    _connectionSub = _service.connectionStates.listen((state) {
      isOnline.value = state.isReady;
      _tryAutoFetchNext();
    });
    _authSub = _service.authStates.listen((state) {
      _isAuthorized = state.isReady;
      _tryAutoFetchNext();
    });
    _settingsWorker = ever<AppSettings>(
      _settingsReader.settingsStream,
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
      _showGeneralError(error);
    } finally {
      loading.value = false;
    }
  }

  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    await mediaController.prepareCurrentMedia(targetMessageId);
  }

  Future<void> skipCurrent([String source = 'unknown']) async {
    final skipped = await actions.skipCurrent(
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
    final maxCount = _settingsReader.currentSettings.batchSize;
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
      final receipt = await actions.classifyCurrent(
        key,
        idBuilder: _buildId,
        nowMs: _nowMs,
      );
      if (receipt == null) {
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
    await navigation.showPrevious();
    await _refreshCurrentMediaIfNeeded();
    await _prefetchIfNeeded();
  }

  Future<void> showNextMessage() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    _stopVideoRefresh();
    if (_currentIndex + 1 < _messageCache.length) {
      await navigation.showNext();
      await _refreshCurrentMediaIfNeeded();
      await _prefetchIfNeeded();
      return;
    }
    await _appendMoreMessages();
    if (_currentIndex + 1 < _messageCache.length) {
      await navigation.showNext();
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
      final undone = await actions.undoLastSuccess(
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
      await actions.retryNextFailed(
        idBuilder: _buildId,
        nowMs: _nowMs,
      );
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    }
  }

  Future<void> recoverPendingTransactionsIfNeeded() =>
      recovery.recoverPendingTransactionsIfNeeded();

  Future<void> _delayThrottle() async {
    final delayMs = _settingsReader.currentSettings.throttleMs;
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
    final resolved = _errorMapper.mapTdlibFailure(error);
    _reportError(resolved.title, resolved.message);
  }

  void _showGeneralError(Object error) {
    final resolved = _errorMapper.mapGeneralError(error);
    _reportError(resolved.title, resolved.message);
  }

  void _tryAutoFetchNext() {
    if (!_isAuthorized || !isOnline.value || loading.value) {
      return;
    }
    if (!recovery.isCompleted) {
      _triggerTransactionRecoveryIfNeeded();
      return;
    }
    if (currentMessage.value != null) {
      return;
    }
    unawaited(fetchNext());
  }

  void _triggerTransactionRecoveryIfNeeded() {
    if (recovery.isRunning || recovery.isCompleted) {
      return;
    }
    unawaited(_recoverPendingTransactions());
  }

  Future<void> _recoverPendingTransactions() async {
    await recovery.recoverPendingTransactionsIfNeeded();
    if (recovery.isCompleted) {
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
    _remainingCountService.beginRequest();
    navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    _tailMessageId = null;
    remainingCount.value = null;
    remainingCountLoading.value = false;
  }

  Future<void> _refreshCurrentMediaIfNeeded() async {
    await mediaController.refreshCurrentMediaIfNeeded();
  }

  Future<void> _loadInitialMessages() async {
    unawaited(_refreshRemainingCount());
    navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    _tailMessageId = null;
    final page = await _messageReadGateway.fetchMessagePage(
      direction: _settingsReader.currentSettings.fetchDirection,
      sourceChatId: _settingsReader.currentSettings.sourceChatId,
      fromMessageId: null,
      limit: _messagePageSize,
    );
    navigation.replaceMessages(page);
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
    final page = await _messageReadGateway.fetchMessagePage(
      direction: _settingsReader.currentSettings.fetchDirection,
      sourceChatId: _settingsReader.currentSettings.sourceChatId,
      fromMessageId: _tailMessageId,
      limit: _messagePageSize,
    );
    if (page.isEmpty) {
      return;
    }
    navigation.appendUniqueMessages(page);
    _tailMessageId = _messageCache.last.id;
  }

  Future<void> _prefetchIfNeeded() async {
    if (_shouldAppendMoreMessages()) {
      await _appendMoreMessages();
    }
    await _prepareUpcomingPreviews();
  }

  Future<void> _ensureVisibleMessage() async {
    if (navigation.isEmpty) {
      await _appendMoreMessages();
    }
    navigation.ensureCurrentAndSync();
    if (navigation.isEmpty) {
      return;
    }
    await _refreshCurrentMediaIfNeeded();
    await _prefetchIfNeeded();
  }

  void _stopVideoRefresh() {
    mediaController.stop();
  }

  Future<void> _refreshRemainingCount() async {
    await _remainingCountService.refreshRemainingCount(
      loadCount: () => _messageReadGateway.countRemainingMessages(
        sourceChatId: _settingsReader.currentSettings.sourceChatId,
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
    final prefetchCount = _settingsReader.currentSettings.previewPrefetchCount;
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
        await _mediaGateway.prepareMediaPreview(
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
