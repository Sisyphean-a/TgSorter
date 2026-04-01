import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  group('PipelineController', () {
    late _FakeTelegramService service;
    late SettingsController settingsController;
    late OperationJournalRepository journalRepository;
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
          CategoryConfig(key: 'a', name: '分类 A', targetChatId: 10001),
          CategoryConfig(key: 'b', name: '分类 B', targetChatId: 10002),
          CategoryConfig(key: 'c', name: '分类 C', targetChatId: 10003),
        ],
        sourceChatId: 8888,
        fetchDirection: MessageFetchDirection.latestFirst,
        batchSize: 2,
        throttleMs: 0,
      );
      journalRepository = OperationJournalRepository(prefs);
      controller = PipelineController(
        service: service,
        settingsController: settingsController,
        journalRepository: journalRepository,
      );
      controller.onInit();
      service.emitConnectionReady();
    });

    tearDown(() {
      controller.onClose();
    });

    test('skipCurrent fetches next message', () async {
      service.nextMessages.addAll([
        _message(10, 'first'),
        _message(11, 'second'),
      ]);
      await controller.fetchNext();
      expect(controller.currentMessage.value?.id, 10);

      await controller.skipCurrent();

      expect(controller.currentMessage.value?.id, 11);
    });

    test('runBatch uses settings batchSize as upper bound', () async {
      service.nextMessages.addAll([
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
  });
}

class _FakeTelegramService implements TelegramGateway {
  final _connectionController = StreamController<ConnectionState>.broadcast();

  final List<PipelineMessage?> nextMessages = <PipelineMessage?>[];
  final List<int> classifiedMessageIds = <int>[];
  int? lastFetchSourceChatId;

  @override
  Stream<AuthorizationState> get authStates => const Stream.empty();

  @override
  Stream<ConnectionState> get connectionStates => _connectionController.stream;

  void emitConnectionReady() {
    _connectionController.add(const ConnectionStateReady());
  }

  @override
  Future<void> start() async {}

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
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    lastFetchSourceChatId = sourceChatId;
    if (nextMessages.isEmpty) {
      return null;
    }
    return nextMessages.removeAt(0);
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required int messageId,
    required int targetChatId,
  }) async {
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
