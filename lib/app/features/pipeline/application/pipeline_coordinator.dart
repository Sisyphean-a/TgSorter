import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_port.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

import 'pipeline_action_service.dart';
import 'pipeline_error_mapper.dart';
import 'pipeline_feed_controller.dart';
import 'pipeline_lifecycle_coordinator.dart';
import 'pipeline_media_controller.dart';
import 'pipeline_media_refresh_service.dart';
import 'pipeline_media_session_controller.dart';
import 'pipeline_screen_view_model.dart';
import 'media_session_projector.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_recovery_service.dart';
import 'pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'remaining_count_service.dart';

class PipelineCoordinator extends GetxController
    implements PipelineLogsPort, SkippedMessageRestorePort {
  static const Duration _videoRefreshInterval = Duration(seconds: 1);

  PipelineCoordinator({
    required AuthStateGateway authStateGateway,
    required ConnectionStateGateway connectionStateGateway,
    required MessageReadGateway messageReadGateway,
    required MediaGateway mediaGateway,
    required ClassifyGateway classifyGateway,
    RecoveryGateway? recoveryGateway,
    required PipelineSettingsReader settingsReader,
    required OperationJournalRepository journalRepository,
    SkippedMessageRepository? skippedMessageRepository,
    required AppErrorController errorController,
    PipelineRuntimeState? runtimeState,
    PipelineNavigationService? navigation,
    PipelineActionService? actions,
    PipelineRecoveryService? recovery,
    PipelineMediaRefreshService? mediaRefresh,
    PipelineMediaSessionController? mediaSessionController,
    PipelineFeedController? feedController,
    PipelineLifecycleCoordinator? lifecycle,
    RemainingCountService? remainingCountService,
  }) : _authStateGateway = authStateGateway,
       _connectionStateGateway = connectionStateGateway,
       _settingsReader = settingsReader,
       _journalRepository = journalRepository,
       _errorController = errorController,
       _errorMapper = const PipelineErrorMapper(),
       _messageReadGateway = messageReadGateway,
       _mediaGateway = mediaGateway,
       _classifyGateway = classifyGateway,
       _recoveryGateway = recoveryGateway,
       runtimeState = runtimeState ?? PipelineRuntimeState() {
    final resolvedNavigation =
        navigation ?? PipelineNavigationService(state: this.runtimeState);
    final resolvedActions =
        actions ??
        PipelineActionService(
          state: this.runtimeState,
          navigation: resolvedNavigation,
          classifyGateway: _classifyGateway,
          settings: settingsReader,
          journalRepository: journalRepository,
          skippedMessageRepository: skippedMessageRepository,
          workflow: SkippedMessageWorkflow.forwarding,
          logs: logs,
          retryQueue: retryQueue,
        );
    final resolvedRecovery =
        recovery ??
        PipelineRecoveryService(
          recoveryGateway: _recoveryGateway,
          errors: errorController,
        );
    final resolvedMediaRefresh =
        mediaRefresh ??
        PipelineMediaRefreshService.legacy(
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
      settingsReader: settingsReader,
      appendLog: _appendMediaLog,
      logIdBuilder: _buildId,
      nowMs: _nowMs,
      reportGeneralError: _showGeneralError,
      videoRefreshInterval: _videoRefreshInterval,
    );
    this.mediaSessionController =
        mediaSessionController ??
        PipelineMediaSessionController(
          state: this.runtimeState,
          legacyController: mediaController,
          projector: const MediaSessionProjector(),
        );
    final resolvedRemainingCountService =
        remainingCountService ?? RemainingCountService();
    this.feedController =
        feedController ??
        PipelineFeedController(
          state: this.runtimeState,
          navigation: resolvedNavigation,
          messages: _messageReadGateway,
          media: _mediaGateway,
          settings: settingsReader,
          remainingCount: resolvedRemainingCountService,
          reportGeneralError: _showGeneralError,
          skippedMessageRepository: skippedMessageRepository,
          workflow: SkippedMessageWorkflow.forwarding,
          refreshCurrentMediaIfNeeded: _refreshCurrentMediaIfNeeded,
        );
    this.lifecycle =
        lifecycle ??
        PipelineLifecycleCoordinator(
          state: this.runtimeState,
          settings: settingsReader,
          recovery: resolvedRecovery,
          onFetchNext: fetchNext,
          onResetPipeline: _resetPipelineState,
        );
  }

  final AuthStateGateway _authStateGateway;
  final ConnectionStateGateway _connectionStateGateway;
  final PipelineSettingsReader _settingsReader;
  final OperationJournalRepository _journalRepository;
  final AppErrorController _errorController;
  final PipelineErrorMapper _errorMapper;
  final PipelineRuntimeState runtimeState;
  final MessageReadGateway _messageReadGateway;
  final MediaGateway _mediaGateway;
  final ClassifyGateway _classifyGateway;
  final RecoveryGateway? _recoveryGateway;
  late final PipelineNavigationService navigation;
  late final PipelineActionService actions;
  late final PipelineRecoveryService recovery;
  late final PipelineMediaRefreshService mediaRefresh;
  late final PipelineMediaController mediaController;
  late final PipelineMediaSessionController mediaSessionController;
  late final PipelineFeedController feedController;
  late final PipelineLifecycleCoordinator lifecycle;

  Rxn<PipelineMessage> get currentMessage => runtimeState.currentMessage;
  RxBool get loading => runtimeState.loading;
  RxBool get processing => runtimeState.processing;
  RxBool get videoPreparing => runtimeState.videoPreparing;
  RxBool get isOnline => runtimeState.isOnline;
  final logs = <ClassifyOperationLog>[].obs;
  final pendingRecoveryTransactions = <ClassifyTransactionEntry>[].obs;
  final retryQueue = <RetryQueueItem>[].obs;
  RxBool get canShowPrevious => runtimeState.canShowPrevious;
  RxBool get canShowNext => runtimeState.canShowNext;
  RxBool get remainingCountLoading => runtimeState.remainingCountLoading;
  RxnInt get remainingCount => runtimeState.remainingCount;
  PipelineScreenVm get screenVm => PipelineScreenVm(
    message: MessagePreviewVm(
      content: currentMessage.value,
      media: MediaSessionVm.fromState(runtimeState.mediaSession.value),
    ),
    navigation: NavigationVm(
      canShowPrevious: runtimeState.navigation.value.canShowPrevious,
      canShowNext: runtimeState.navigation.value.canShowNext,
    ),
    workflow: WorkflowVm(
      processingOverlay: loading.value || processing.value,
      online: isOnline.value,
    ),
  );

  @override
  List<ClassifyOperationLog> get logsSnapshot => logs.toList(growable: false);

  @override
  SkippedMessageWorkflow get workflow => SkippedMessageWorkflow.forwarding;

  StreamSubscription<TdConnectionState>? _connectionSub;
  StreamSubscription<TdAuthState>? _authSub;
  Worker? _settingsWorker;
  ClassifyReceipt? _lastSuccessReceipt;
  Future<void>? _showNextTask;
  bool _authorized = false;

  List<PipelineMessage> get _messageCache => runtimeState.cache;
  int get _currentIndex => runtimeState.currentIndex;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _reloadPendingRecoveryTransactions();
    _connectionSub = _connectionStateGateway.connectionStates.listen((state) {
      lifecycle.updateConnection(state.isReady);
    });
    _authSub = _authStateGateway.authStates.listen((state) {
      _authorized = state.isReady;
      lifecycle.updateAuthorization(state.isReady);
    });
    _settingsWorker = ever<AppSettings>(
      _settingsReader.settingsStream,
      lifecycle.handleSettingsChanged,
    );
  }

  @override
  void onReady() {
    super.onReady();
    lifecycle.tryAutoFetchNext();
  }

  Future<void> fetchNext() async {
    _stopVideoRefresh();
    loading.value = true;
    try {
      await feedController.loadInitialMessages();
      await _refreshCurrentMediaIfNeeded();
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    } catch (error) {
      _showGeneralError(error);
    } finally {
      loading.value = false;
      lifecycle.handleFetchCompleted();
    }
  }

  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    await mediaSessionController.requestPlayback(targetMessageId);
  }

  Future<void> performMediaAction(MediaAction action) async {
    switch (action) {
      case OpenInApp(:final messageId):
        await prepareCurrentMedia(messageId);
        return;
      case OpenExternally():
      case RevealInFolder():
      case CopyPath():
      case OpenLink():
        return;
    }
  }

  bool isPreparingMedia(int? messageId) {
    return mediaSessionController.isPreparingMessageId(messageId);
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
    feedController.decrementRemainingCount(1);
    await feedController.ensureVisibleMessage();
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
      final ok = await classify(key);
      if (!ok) {
        break;
      }
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
      feedController.decrementRemainingCount(receipt.sourceMessageIds.length);
      await feedController.ensureVisibleMessage();
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
    await feedController.prefetchIfNeeded();
  }

  Future<void> showNextMessage() async {
    final inFlight = _showNextTask;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final task = _showNextMessageInternal();
    _showNextTask = task;
    try {
      await task;
    } finally {
      if (identical(_showNextTask, task)) {
        _showNextTask = null;
      }
    }
  }

  Future<void> _showNextMessageInternal() async {
    if (processing.value || currentMessage.value == null) {
      return;
    }
    _stopVideoRefresh();
    if (_currentIndex + 1 < _messageCache.length) {
      await navigation.showNext();
      await _refreshCurrentMediaIfNeeded();
      await feedController.prefetchIfNeeded();
      return;
    }
    await feedController.appendMoreMessages();
    if (_currentIndex + 1 < _messageCache.length) {
      await navigation.showNext();
      await _refreshCurrentMediaIfNeeded();
      await feedController.prefetchIfNeeded();
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
      feedController.incrementRemainingCount(receipt.sourceMessageIds.length);
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
      await actions.retryNextFailed(idBuilder: _buildId, nowMs: _nowMs);
    } on TdlibFailure catch (error) {
      _showTdlibError(error);
    }
  }

  Future<void> recoverPendingTransactionsIfNeeded() async {
    await _recoverPendingTransactionsAndReload();
  }

  Future<void> markPendingRecoveryTransactionResolved(String id) async {
    await _journalRepository.removeClassifyTransaction(id);
    _reloadPendingRecoveryTransactions();
  }

  Future<void> markAllPendingRecoveryTransactionsResolved() async {
    final ids = pendingRecoveryTransactions.map((item) => item.id).toList();
    for (final id in ids) {
      await _journalRepository.removeClassifyTransaction(id);
    }
    _reloadPendingRecoveryTransactions();
  }

  Future<void> recheckPendingRecoveryTransactions() async {
    recovery.reset();
    await _recoverPendingTransactionsAndReload();
  }

  Future<void> clearSessionStateForLogout() async {
    _stopVideoRefresh();
    _resetPipelineState();
    _lastSuccessReceipt = null;
    logs.clear();
    retryQueue.clear();
    pendingRecoveryTransactions.clear();
    await _journalRepository.saveLogs(const []);
    await _journalRepository.saveRetryQueue(const []);
    await _journalRepository.saveClassifyTransactions(const []);
  }

  @override
  Future<void> reloadAfterSkippedRestore({int? sourceChatId}) async {
    final activeSourceChatId = _settingsReader.currentSettings.sourceChatId;
    if (activeSourceChatId == null) {
      return;
    }
    if (sourceChatId != null && sourceChatId != activeSourceChatId) {
      return;
    }
    _resetPipelineState();
    if (!_authorized || !isOnline.value || loading.value) {
      return;
    }
    await fetchNext();
  }

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
    final event = _errorMapper.mapTdlibFailure(error);
    _reportError(event);
  }

  void _showGeneralError(Object error) {
    final event = _errorMapper.mapGeneralError(error);
    _reportError(event);
  }

  void _resetPipelineState() {
    _stopVideoRefresh();
    feedController.reset();
  }

  Future<void> _refreshCurrentMediaIfNeeded() async {
    await mediaSessionController.refreshCurrentMediaIfNeeded();
  }

  Future<void> _appendMediaLog(ClassifyOperationLog log) async {
    logs.insert(0, log);
    await _journalRepository.saveLogs(List<ClassifyOperationLog>.from(logs));
  }

  Future<void> _recoverPendingTransactionsAndReload() async {
    await recovery.recoverPendingTransactionsIfNeeded();
    _reloadPendingRecoveryTransactions();
  }

  void _stopVideoRefresh() {
    mediaSessionController.stop();
  }

  void _reportError(AppErrorEvent event) {
    _errorController.reportEvent(event);
  }

  void _reloadPendingRecoveryTransactions() {
    pendingRecoveryTransactions.assignAll(
      _journalRepository.loadClassifyTransactions(),
    );
  }

  @override
  void onClose() {
    _stopVideoRefresh();
    mediaSessionController.dispose();
    _connectionSub?.cancel();
    _authSub?.cancel();
    _settingsWorker?.dispose();
    super.onClose();
  }
}
