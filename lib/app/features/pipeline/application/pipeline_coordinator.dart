import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

import 'pipeline_action_service.dart';
import 'pipeline_error_mapper.dart';
import 'pipeline_feed_controller.dart';
import 'pipeline_lifecycle_coordinator.dart';
import 'pipeline_media_controller.dart';
import 'pipeline_media_refresh_service.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_recovery_service.dart';
import 'pipeline_runtime_state.dart';
import 'pipeline_settings_reader.dart';
import 'remaining_count_service.dart';

class PipelineCoordinator extends GetxController {
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
    required AppErrorController errorController,
    PipelineRuntimeState? runtimeState,
    PipelineNavigationService? navigation,
    PipelineActionService? actions,
    PipelineRecoveryService? recovery,
    PipelineMediaRefreshService? mediaRefresh,
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
  late final PipelineFeedController feedController;
  late final PipelineLifecycleCoordinator lifecycle;

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

  List<PipelineMessage> get _messageCache => runtimeState.cache;
  int get _currentIndex => runtimeState.currentIndex;

  @override
  void onInit() {
    super.onInit();
    logs.assignAll(_journalRepository.loadLogs());
    retryQueue.assignAll(_journalRepository.loadRetryQueue());
    _connectionSub = _connectionStateGateway.connectionStates.listen((state) {
      lifecycle.updateConnection(state.isReady);
    });
    _authSub = _authStateGateway.authStates.listen((state) {
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
    await mediaController.refreshCurrentMediaIfNeeded();
  }

  void _stopVideoRefresh() {
    mediaController.stop();
  }

  void _reportError(AppErrorEvent event) {
    _errorController.reportEvent(event);
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
