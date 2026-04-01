import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  group('PipelineController', () {
    late _FakeTelegramService service;
    late SettingsController settingsController;
    late OperationJournalRepository journalRepository;
    late AppErrorController errorController;
    late PipelineController controller;

    setUp(() async {
      Get.testMode = true;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = _FakeTelegramService();
      settingsController = SettingsController(
        SettingsRepository(prefs),
        service,
      );
      settingsController.onInit();
      settingsController.settings.value = const AppSettings(
        categories: [
          CategoryConfig(key: 'a', targetChatId: 10001, targetChatTitle: '分类一'),
          CategoryConfig(key: 'b', targetChatId: 10002, targetChatTitle: '分类二'),
          CategoryConfig(key: 'c', targetChatId: 10003, targetChatTitle: '分类三'),
        ],
        sourceChatId: 8888,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 2,
        throttleMs: 0,
        proxy: ProxySettings.empty,
      );
      journalRepository = OperationJournalRepository(prefs);
      errorController = AppErrorController();
      controller = PipelineController(
        service: service,
        settingsController: settingsController,
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
      service.pages.add([
        _message(10, 'first'),
        _message(11, 'second'),
      ]);
      await controller.fetchNext();
      expect(controller.currentMessage.value?.id, 10);

      await controller.skipCurrent();

      expect(controller.currentMessage.value?.id, 11);
    });

    test('runBatch uses settings batchSize as upper bound', () async {
      service.pages.add([
        _message(1, '1'),
        _message(2, '2'),
        _message(3, '3'),
      ]);
      await controller.fetchNext();

      await controller.runBatch('a');

      expect(service.classifiedMessageIds, [1, 2]);
      expect(controller.currentMessage.value?.id, 3);
    });

    test('fetchNext passes sourceChatId from settings', () async {
      await controller.fetchNext();

      expect(service.lastFetchSourceChatId, 8888);
    });

    test('showPreviousMessage returns to prior cached message', () async {
      service.pages.add([
        _message(31, 'a'),
        _message(32, 'b'),
      ]);
      await controller.fetchNext();
      await controller.showNextMessage();

      expect(controller.currentMessage.value?.id, 32);

      await controller.showPreviousMessage();

      expect(controller.currentMessage.value?.id, 31);
    });

    test('does not auto fetch before authorization is ready', () async {
      controller.onClose();
      controller = PipelineController(
        service: service,
        settingsController: settingsController,
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

    test('prepareCurrentVideo requests download and refreshes current message', () async {
      service.pages.add([
        _videoMessage(
          id: 21,
          title: '#REDPMV 005 高跟鞋',
          localVideoPath: null,
        ),
      ]);
      service.refreshedMessage = _videoMessage(
        id: 21,
        title: '#REDPMV 005 高跟鞋',
        localVideoPath: 'C:/video.mp4',
      );
      await controller.fetchNext();

      await controller.prepareCurrentVideo();
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(service.videoRequestCount, 1);
      expect(controller.currentMessage.value?.preview.localVideoPath, 'C:/video.mp4');
      expect(controller.videoPreparing.value, isFalse);
    });
  });
}

class _FakeTelegramService implements TelegramGateway {
  final _authController = StreamController<TdAuthState>.broadcast();
  final _connectionController = StreamController<TdConnectionState>.broadcast();

  final List<List<PipelineMessage>> pages = <List<PipelineMessage>>[];
  final List<int> classifiedMessageIds = <int>[];
  int? lastFetchSourceChatId;
  int fetchNextCalls = 0;
  int videoRequestCount = 0;
  bool? lastAsCopy;
  PipelineMessage? refreshedMessage;

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  @override
  Stream<TdConnectionState> get connectionStates => _connectionController.stream;

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
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    fetchNextCalls++;
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
  Future<PipelineMessage> prepareVideoPlayback({
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
    return refreshedMessage ?? _videoMessage(id: messageId, title: 'video');
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required int messageId,
    required int targetChatId,
    required bool asCopy,
  }) async {
    lastAsCopy = asCopy;
    classifiedMessageIds.add(messageId);
    return ClassifyReceipt(
      sourceChatId: 777,
      sourceMessageId: messageId,
      targetChatId: targetChatId,
      targetMessageId: messageId + 1000,
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required int targetMessageId,
  }) async {}
}

PipelineMessage _message(int id, String title) {
  return PipelineMessage(
    id: id,
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}

PipelineMessage _videoMessage({
  required int id,
  required String title,
  String? localVideoPath,
}) {
  return PipelineMessage(
    id: id,
    sourceChatId: 8888,
    preview: MessagePreview(
      kind: MessagePreviewKind.video,
      title: title,
      localVideoPath: localVideoPath,
      videoDurationSeconds: 688,
    ),
  );
}
