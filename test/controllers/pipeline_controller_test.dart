import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_action_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_refresh_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

void main() {
  group('PipelineCoordinator', () {
    late _FakePipelineGateway service;
    late _TestPipelineSettingsProvider settingsProvider;
    late OperationJournalRepository journalRepository;
    late AppErrorController errorController;
    late PipelineCoordinator controller;

    setUp(() async {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = _FakePipelineGateway();
      settingsProvider = _TestPipelineSettingsProvider(
        const AppSettings(
          categories: [
            CategoryConfig(
              key: 'a',
              targetChatId: 10001,
              targetChatTitle: '分类一',
            ),
            CategoryConfig(
              key: 'b',
              targetChatId: 10002,
              targetChatTitle: '分类二',
            ),
            CategoryConfig(
              key: 'c',
              targetChatId: 10003,
              targetChatTitle: '分类三',
            ),
          ],
          sourceChatId: 8888,
          fetchDirection: MessageFetchDirection.latestFirst,
          forwardAsCopy: false,
          batchSize: 2,
          throttleMs: 0,
          proxy: ProxySettings.empty,
        ),
      );
      journalRepository = OperationJournalRepository(prefs);
      errorController = AppErrorController();
      controller = PipelineCoordinator(
        authStateGateway: service,
        connectionStateGateway: service,
        messageReadGateway: service,
        mediaGateway: service,
        classifyGateway: service,
        recoveryGateway: service,
        settingsReader: settingsProvider,
        journalRepository: journalRepository,
        errorController: errorController,
      );
      controller.onInit();
      service.emitAuthReady();
      service.emitConnectionReady();
    });

    tearDown(() {
      controller.onClose();
    });

    test('skipCurrent advances to next cached message', () async {
      service.pages.add([_message(10, 'first'), _message(11, 'second')]);
      await controller.fetchNext();
      expect(controller.currentMessage.value?.id, 10);

      await controller.skipCurrent();

      expect(controller.currentMessage.value?.id, 11);
    });

    test('runBatch uses settings batchSize as upper bound', () async {
      service.pages.add([_message(1, '1'), _message(2, '2'), _message(3, '3')]);
      await controller.fetchNext();

      await controller.runBatch('a');

      expect(service.classifiedMessageIds, [1, 2]);
      expect(controller.currentMessage.value?.id, 3);
    });

    test('fetchNext passes sourceChatId from settings', () async {
      service.remainingCount = 42;
      await controller.fetchNext();

      expect(service.lastFetchSourceChatId, 8888);
      expect(controller.remainingCount.value, 42);
    });

    test(
      'fetchNext shows first message before remaining count finishes',
      () async {
        service.remainingCountCompleter = Completer<int>();
        service.pages.add([_message(10, 'first')]);

        final fetchFuture = controller.fetchNext();

        await _waitFor(() => controller.currentMessage.value?.id == 10);

        expect(controller.currentMessage.value?.id, 10);
        expect(controller.loading.value, isFalse);
        expect(controller.remainingCountLoading.value, isTrue);
        expect(controller.remainingCount.value, isNull);

        service.remainingCountCompleter!.complete(1250);
        await fetchFuture;
        await _waitFor(() => controller.remainingCount.value == 1250);

        expect(controller.remainingCount.value, 1250);
        expect(controller.remainingCountLoading.value, isFalse);
      },
    );

    test(
      'fetchNext clears loading once first message is visible even if preview prefetch is still running',
      () async {
        service.previewPreparationCompleter = Completer<void>();
        service.blockedPreviewMessageId = 11;
        service.pages.add([_message(10, 'first'), _message(11, 'second')]);

        final fetchFuture = controller.fetchNext();

        await _waitFor(() => controller.currentMessage.value?.id == 10);

        expect(controller.currentMessage.value?.id, 10);
        expect(controller.loading.value, isFalse);

        service.previewPreparationCompleter!.complete();
        await fetchFuture;
      },
    );

    test('showPreviousMessage returns to prior cached message', () async {
      service.pages.add([_message(31, 'a'), _message(32, 'b')]);
      await controller.fetchNext();
      await controller.showNextMessage();

      expect(controller.currentMessage.value?.id, 32);

      await controller.showPreviousMessage();

      expect(controller.currentMessage.value?.id, 31);
    });

    test(
      'changing fetch direction invalidates cache and reloads pipeline',
      () async {
        service.pages.add([_message(31, 'latest'), _message(30, 'older')]);
        service.pages.add([_message(1, 'oldest'), _message(2, 'next oldest')]);
        await controller.fetchNext();

        expect(controller.currentMessage.value?.id, 31);

        settingsProvider.update(
          settingsProvider.currentSettings.updateFetchDirection(
            MessageFetchDirection.oldestFirst,
          ),
        );
        await _waitFor(() => controller.currentMessage.value?.id == 1);

        expect(controller.currentMessage.value?.id, 1);
        expect(controller.canShowPrevious.value, isFalse);
        expect(controller.canShowNext.value, isTrue);
        expect(service.fetchDirections.last, MessageFetchDirection.oldestFirst);
        expect(
          service.fetchDirections.where(
            (item) => item == MessageFetchDirection.oldestFirst,
          ),
          isNotEmpty,
        );
      },
    );

    test(
      'changing fetch direction during in-flight fetch reloads with new settings',
      () async {
        final initialPage = Completer<List<PipelineMessage>>();
        service.pageCompleter = initialPage;
        controller.onClose();
        controller = PipelineCoordinator(
          authStateGateway: service,
          connectionStateGateway: service,
          messageReadGateway: service,
          mediaGateway: service,
          classifyGateway: service,
          recoveryGateway: service,
          settingsReader: settingsProvider,
          journalRepository: journalRepository,
          errorController: errorController,
        );
        controller.onInit();
        service.emitAuthReady();
        service.emitConnectionReady();
        await _waitFor(() => controller.loading.value);

        service.pages.add([_message(1, 'oldest')]);
        settingsProvider.update(
          settingsProvider.currentSettings.updateFetchDirection(
            MessageFetchDirection.oldestFirst,
          ),
        );
        initialPage.complete([_message(31, 'latest')]);
        await Future<void>.delayed(Duration.zero);
        await _waitFor(() => controller.currentMessage.value?.id == 1);

        expect(service.fetchNextCalls, 2);
        expect(controller.currentMessage.value?.id, 1);
        expect(service.fetchDirections.last, MessageFetchDirection.oldestFirst);
      },
    );

    test('does not auto fetch before authorization is ready', () async {
      controller.onClose();
      controller = PipelineCoordinator(
        authStateGateway: service,
        connectionStateGateway: service,
        messageReadGateway: service,
        mediaGateway: service,
        classifyGateway: service,
        recoveryGateway: service,
        settingsReader: settingsProvider,
        journalRepository: journalRepository,
        errorController: errorController,
      );
      controller.onInit();
      service.emitConnectionReady();
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchNextCalls, 0);

      service.emitAuthReady();
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchNextCalls, 1);
    });

    test('auto fetch waits transaction recovery before first fetch', () async {
      controller.onClose();
      controller = PipelineCoordinator(
        authStateGateway: service,
        connectionStateGateway: service,
        messageReadGateway: service,
        mediaGateway: service,
        classifyGateway: service,
        recoveryGateway: service,
        settingsReader: settingsProvider,
        journalRepository: journalRepository,
        errorController: errorController,
      );
      controller.onInit();
      service.recoveryCompleter = Completer<ClassifyRecoverySummary>();

      service.emitConnectionReady();
      service.emitAuthReady();
      await Future<void>.delayed(Duration.zero);

      expect(service.recoveryCalls, 1);
      expect(service.fetchNextCalls, 0);

      service.recoveryCompleter!.complete(ClassifyRecoverySummary.empty);
      await Future<void>.delayed(Duration.zero);

      expect(service.fetchNextCalls, 1);
    });

    test(
      'prepareCurrentMedia requests download and refreshes current message',
      () async {
        service.pages.add([
          _videoMessage(id: 21, title: '#REDPMV 005 高跟鞋', localVideoPath: null),
        ]);
        service.refreshedMessage = _videoMessage(
          id: 21,
          title: '#REDPMV 005 高跟鞋',
          localVideoPath: 'C:/video.mp4',
        );
        await controller.fetchNext();

        await controller.prepareCurrentMedia();
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(service.videoRequestCount, 1);
        expect(
          controller.currentMessage.value?.preview.localVideoPath,
          'C:/video.mp4',
        );
        expect(controller.videoPreparing.value, isFalse);
      },
    );

    test(
      'showNextMessage starts media refresh for next cached video item',
      () async {
        service.pages.add([
          _videoMessage(
            id: 21,
            title: 'first',
            localThumbnailPath: 'C:/thumb-first.jpg',
          ),
          _videoMessage(id: 22, title: 'second', localThumbnailPath: null),
        ]);
        service.refreshedMessages[22] = _videoMessage(
          id: 22,
          title: 'second',
          localThumbnailPath: 'C:/thumb-second.jpg',
        );
        await controller.fetchNext();

        expect(
          controller.currentMessage.value?.preview.localVideoThumbnailPath,
          'C:/thumb-first.jpg',
        );

        await controller.showNextMessage();
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(controller.currentMessage.value?.id, 22);
        expect(
          controller.currentMessage.value?.preview.localVideoThumbnailPath,
          'C:/thumb-second.jpg',
        );
      },
    );

    test('classify decrements remaining count by one pipeline item', () async {
      service.remainingCount = 3;
      service.pages.add([_message(1, '1'), _message(2, '2')]);
      await controller.fetchNext();

      await controller.classify('a');

      expect(controller.remainingCount.value, 2);
    });

    test('classify delegates to injected action service', () async {
      final runtimeState = PipelineRuntimeState();
      final navigation = PipelineNavigationService(state: runtimeState);
      final actions = _RecordingPipelineActionService(
        state: runtimeState,
        navigation: navigation,
        settings: settingsProvider,
        journalRepository: journalRepository,
      );
      controller.onClose();
      controller = PipelineCoordinator(
        authStateGateway: service,
        connectionStateGateway: service,
        messageReadGateway: service,
        mediaGateway: service,
        classifyGateway: service,
        recoveryGateway: service,
        settingsReader: settingsProvider,
        journalRepository: journalRepository,
        errorController: errorController,
        runtimeState: runtimeState,
        navigation: navigation,
        actions: actions,
      );
      controller.onInit();
      service.emitAuthReady();
      service.emitConnectionReady();
      service.pages.add([_message(51, 'delegated')]);
      await controller.fetchNext();

      final ok = await controller.classify('a');

      expect(ok, isTrue);
      expect(actions.classifyCalls, 1);
      expect(actions.lastCategoryKey, 'a');
      expect(service.classifiedMessageIds, isEmpty);
    });

    test('auto fetch delegates recovery to injected service', () async {
      final recovery = _RecordingPipelineRecoveryService(
        errorController: errorController,
      );
      controller.onClose();
      controller = PipelineCoordinator(
        authStateGateway: service,
        connectionStateGateway: service,
        messageReadGateway: service,
        mediaGateway: service,
        classifyGateway: service,
        recoveryGateway: service,
        settingsReader: settingsProvider,
        journalRepository: journalRepository,
        errorController: errorController,
        recovery: recovery,
      );
      controller.onInit();

      service.emitConnectionReady();
      service.emitAuthReady();
      await Future<void>.delayed(Duration.zero);

      expect(recovery.recoverCalls, 1);
      expect(service.recoveryCalls, 0);
    });

    test(
      'prepareCurrentMedia delegates to injected media refresh service',
      () async {
        final mediaRefresh = _RecordingPipelineMediaRefreshService();
        controller.onClose();
        controller = PipelineCoordinator(
          authStateGateway: service,
          connectionStateGateway: service,
          messageReadGateway: service,
          mediaGateway: service,
          classifyGateway: service,
          recoveryGateway: service,
          settingsReader: settingsProvider,
          journalRepository: journalRepository,
          errorController: errorController,
          mediaRefresh: mediaRefresh,
        );
        controller.onInit();
        service.emitAuthReady();
        service.emitConnectionReady();
        service.pages.add([
          _videoMessage(id: 61, title: 'delegated', localVideoPath: null),
        ]);
        await controller.fetchNext();

        await controller.prepareCurrentMedia();

        expect(mediaRefresh.prepareCalls, 1);
        expect(service.videoRequestCount, 0);
      },
    );

    test(
      'fetchNext delegates remaining count refresh to injected service',
      () async {
        final remainingCountService = _RecordingRemainingCountService();
        controller.onClose();
        controller = PipelineCoordinator(
          authStateGateway: service,
          connectionStateGateway: service,
          messageReadGateway: service,
          mediaGateway: service,
          classifyGateway: service,
          recoveryGateway: service,
          settingsReader: settingsProvider,
          journalRepository: journalRepository,
          errorController: errorController,
          remainingCountService: remainingCountService,
        );
        controller.onInit();
        service.emitAuthReady();
        service.emitConnectionReady();
        service.pages.add([_message(71, 'remaining')]);

        await controller.fetchNext();

        expect(remainingCountService.refreshCalls, 1);
        expect(controller.remainingCount.value, 7);
        expect(service.remainingCountCalls, 0);
      },
    );

    test(
      'showNextMessage prefetches previews for next configured items',
      () async {
        settingsProvider.update(
          settingsProvider.currentSettings.copyWith(previewPrefetchCount: 3),
        );
        service.pages.add([
          _videoMessage(id: 1, title: '1'),
          _videoMessage(id: 2, title: '2'),
          _videoMessage(id: 3, title: '3'),
          _videoMessage(id: 4, title: '4'),
        ]);

        await controller.fetchNext();

        await _waitFor(() => service.previewPreparedMessageIds.length == 3);
        expect(service.previewPreparedMessageIds, [2, 3, 4]);

        await controller.showNextMessage();

        expect(service.previewPreparedMessageIds, [2, 3, 4]);
      },
    );
  });
}

class _TestPipelineSettingsProvider implements PipelineSettingsReader {
  _TestPipelineSettingsProvider(AppSettings initialSettings)
    : settingsStream = initialSettings.obs;

  @override
  final Rx<AppSettings> settingsStream;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    return currentSettings.categories.firstWhere((item) => item.key == key);
  }

  void update(AppSettings next) {
    settingsStream.value = next;
  }
}

class _FakePipelineGateway
    implements
        AuthStateGateway,
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway {
  final _authController = StreamController<TdAuthState>.broadcast();
  final _connectionController = StreamController<TdConnectionState>.broadcast();

  final List<List<PipelineMessage>> pages = <List<PipelineMessage>>[];
  final List<int> classifiedMessageIds = <int>[];
  final List<MessageFetchDirection> fetchDirections = <MessageFetchDirection>[];
  final List<int> previewPreparedMessageIds = <int>[];
  int? lastFetchSourceChatId;
  int fetchNextCalls = 0;
  int videoRequestCount = 0;
  bool? lastAsCopy;
  PipelineMessage? refreshedMessage;
  final Map<int, PipelineMessage> refreshedMessages = <int, PipelineMessage>{};
  int remainingCount = 0;
  int remainingCountCalls = 0;
  Completer<int>? remainingCountCompleter;
  Completer<List<PipelineMessage>>? pageCompleter;
  int? blockedPreviewMessageId;
  Completer<void>? previewPreparationCompleter;
  int recoveryCalls = 0;
  Completer<ClassifyRecoverySummary>? recoveryCompleter;

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  @override
  Stream<TdConnectionState> get connectionStates =>
      _connectionController.stream;

  void emitConnectionReady() {
    _connectionController.add(
      const TdConnectionState(
        kind: TdConnectionStateKind.ready,
        rawType: 'connectionStateReady',
      ),
    );
  }

  void emitAuthReady() {
    _authController.add(
      const TdAuthState(
        kind: TdAuthStateKind.ready,
        rawType: 'authorizationStateReady',
      ),
    );
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
    remainingCountCalls++;
    final completer = remainingCountCompleter;
    if (completer != null) {
      return completer.future;
    }
    return remainingCount;
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    fetchNextCalls++;
    fetchDirections.add(direction);
    lastFetchSourceChatId = sourceChatId;
    final completer = pageCompleter;
    if (completer != null) {
      pageCompleter = null;
      return completer.future;
    }
    if (pages.isEmpty) {
      return const [];
    }
    return pages.removeAt(0);
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    previewPreparedMessageIds.add(messageId);
    if (blockedPreviewMessageId == messageId &&
        previewPreparationCompleter != null) {
      await previewPreparationCompleter!.future;
    }
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    videoRequestCount++;
    return refreshedMessage ?? _videoMessage(id: messageId, title: 'video');
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    return refreshedMessages[messageId] ??
        refreshedMessage ??
        _videoMessage(id: messageId, title: 'video');
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    lastAsCopy = asCopy;
    classifiedMessageIds.addAll(messageIds);
    return ClassifyReceipt(
      sourceChatId: 777,
      sourceMessageIds: messageIds,
      targetChatId: targetChatId,
      targetMessageIds: messageIds
          .map((item) => item + 1000)
          .toList(growable: false),
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    recoveryCalls++;
    final completer = recoveryCompleter;
    if (completer != null) {
      return completer.future;
    }
    return ClassifyRecoverySummary.empty;
  }
}

class _RecordingPipelineActionService extends PipelineActionService {
  _RecordingPipelineActionService({
    required super.state,
    required super.navigation,
    required super.settings,
    required super.journalRepository,
  }) : super(classifyGateway: _NoopClassifyGateway());

  int classifyCalls = 0;
  String? lastCategoryKey;
  ClassifyReceipt? _lastReceipt;

  @override
  ClassifyReceipt? get lastReceipt => _lastReceipt;

  @override
  Future<ClassifyReceipt?> classifyCurrent(
    String key, {
    List<ClassifyOperationLog>? logs,
    List<RetryQueueItem>? retryQueue,
    PipelineActionIdBuilder? idBuilder,
    PipelineActionNowMs? nowMs,
  }) async {
    classifyCalls++;
    lastCategoryKey = key;
    _lastReceipt = ClassifyReceipt(
      sourceChatId: 8888,
      sourceMessageIds: <int>[51],
      targetChatId: 10001,
      targetMessageIds: <int>[1051],
    );
    return _lastReceipt;
  }
}

class _RecordingPipelineRecoveryService extends PipelineRecoveryService {
  _RecordingPipelineRecoveryService({
    required AppErrorController errorController,
  }) : super(recoveryGateway: _NoopRecoveryGateway(), errors: errorController);

  int recoverCalls = 0;

  @override
  bool get isCompleted => false;

  @override
  bool get isRunning => false;

  @override
  Future<void> recoverPendingTransactionsIfNeeded() async {
    recoverCalls++;
  }
}

class _RecordingPipelineMediaRefreshService
    extends PipelineMediaRefreshService {
  _RecordingPipelineMediaRefreshService()
    : super(
        mediaGateway: _NoopMediaGateway(),
        messageGateway: _NoopMessageReadGateway(),
      );

  int prepareCalls = 0;

  @override
  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    prepareCalls++;
    return _videoMessage(
      id: messageId,
      title: 'delegated',
      localVideoPath: 'C:/delegated.mp4',
      localThumbnailPath: 'C:/delegated.jpg',
    );
  }
}

class _RecordingRemainingCountService extends RemainingCountService {
  int refreshCalls = 0;

  @override
  Future<void> refreshRemainingCount({
    required Future<int> Function() loadCount,
    required void Function() onStart,
    required void Function(int count) onSuccess,
    required void Function(Object error) onError,
    required void Function() onComplete,
  }) async {
    refreshCalls++;
    onStart();
    onSuccess(7);
    onComplete();
  }
}

class _NoopClassifyGateway implements ClassifyGateway {
  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) {
    throw UnimplementedError();
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

class _NoopRecoveryGateway implements RecoveryGateway {
  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    throw UnimplementedError();
  }
}

class _NoopMediaGateway implements MediaGateway {
  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

class _NoopMessageReadGateway implements MessageReadGateway {
  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    throw UnimplementedError();
  }
}

PipelineMessage _message(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: [id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}

PipelineMessage _videoMessage({
  required int id,
  required String title,
  String? localVideoPath,
  String? localThumbnailPath,
}) {
  return PipelineMessage(
    id: id,
    messageIds: [id],
    sourceChatId: 8888,
    preview: MessagePreview(
      kind: MessagePreviewKind.video,
      title: title,
      localVideoPath: localVideoPath,
      localVideoThumbnailPath: localThumbnailPath,
      videoDurationSeconds: 688,
    ),
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
