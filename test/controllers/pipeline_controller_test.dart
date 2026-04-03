import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_settings_provider.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  group('PipelineController', () {
    late _FakeTelegramService service;
    late _TestPipelineSettingsProvider settingsProvider;
    late OperationJournalRepository journalRepository;
    late AppErrorController errorController;
    late PipelineController controller;

    setUp(() async {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = _FakeTelegramService();
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
      controller = PipelineController(
        service: service,
        settingsProvider: settingsProvider,
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

    test('does not auto fetch before authorization is ready', () async {
      controller.onClose();
      controller = PipelineController(
        service: service,
        settingsProvider: settingsProvider,
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
      controller = PipelineController(
        service: service,
        settingsProvider: settingsProvider,
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

        expect(service.previewPreparedMessageIds, [2, 3, 4]);

        await controller.showNextMessage();

        expect(service.previewPreparedMessageIds, [2, 3, 4]);
      },
    );
  });
}

class _TestPipelineSettingsProvider implements PipelineSettingsProvider {
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

class _FakeTelegramService
    implements TelegramGateway, RecoverableClassifyGateway {
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
  Completer<int>? remainingCountCompleter;
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
  Future<void> start() async {}

  @override
  Future<void> restart() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    return const [];
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
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
