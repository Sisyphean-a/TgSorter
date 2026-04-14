import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/workbench/application/message_workbench_controller.dart';
import 'package:tgsorter/app/features/workbench/application/message_workbench_state.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  group('MessageWorkbenchController', () {
    test(
      'fetchNext loads the initial page with injected source settings',
      () async {
        final messages = _FakeMessageReadGateway([
          _message(1, 'first', sourceChatId: -1001),
        ]);
        final controller = MessageWorkbenchController(
          state: MessageWorkbenchState(),
          messages: messages,
          media: _FakeMediaGateway(),
          settings: _SettingsReader(sourceChatId: -1001),
          reportError: (_) {},
        );

        await controller.fetchNext();

        expect(controller.currentMessage.value?.id, 1);
        expect(messages.lastSourceChatId, -1001);
      },
    );

    test('showNext appends more messages when cache is exhausted', () async {
      final messages = _FakeMessageReadGateway([
        _message(1, 'first'),
        _message(2, 'second'),
      ]);
      final controller = MessageWorkbenchController(
        state: MessageWorkbenchState(),
        messages: messages,
        media: _FakeMediaGateway(),
        settings: _SettingsReader(sourceChatId: 888),
        reportError: (_) {},
      );
      controller.isOnline.value = true;

      await controller.fetchNext();
      await controller.showNextMessage();

      expect(controller.currentMessage.value?.id, 2);
    });

    test('showNext preserves repeated next intents while append is in flight', () async {
      final messages = _DelayedPageMessageReadGateway(
        firstPage: <PipelineMessage>[_message(1, 'first')],
        secondPage: <PipelineMessage>[
          _message(2, 'second'),
          _message(3, 'third'),
        ],
      );
      final controller = MessageWorkbenchController(
        state: MessageWorkbenchState(),
        messages: messages,
        media: _FakeMediaGateway(),
        settings: _SettingsReader(sourceChatId: 888),
        reportError: (_) {},
      );
      controller.isOnline.value = true;

      await controller.fetchNext();
      final firstTap = controller.showNextMessage();
      final secondTap = controller.showNextMessage();
      messages.releaseSecondPage();

      await firstTap;
      await secondTap;

      expect(controller.currentMessage.value?.id, 3);
    });

    test('skipCurrent removes the current message', () async {
      final controller = MessageWorkbenchController(
        state: MessageWorkbenchState(),
        messages: _FakeMessageReadGateway([
          _message(1, 'first'),
          _message(2, 'second'),
        ]),
        media: _FakeMediaGateway(),
        settings: _SettingsReader(sourceChatId: 888),
        reportError: (_) {},
      );
      controller.isOnline.value = true;

      await controller.fetchNext();
      await controller.skipCurrent();

      expect(controller.currentMessage.value?.id, 2);
    });

    test('replaceCurrent updates current message in cache', () async {
      final controller = MessageWorkbenchController(
        state: MessageWorkbenchState(),
        messages: _FakeMessageReadGateway([_message(1, 'old')]),
        media: _FakeMediaGateway(),
        settings: _SettingsReader(sourceChatId: 888),
        reportError: (_) {},
      );

      await controller.fetchNext();
      controller.replaceCurrent(_message(1, 'new'));

      expect(controller.currentMessage.value?.preview.title, 'new');
    });
  });
}

class _FakeMessageReadGateway implements MessageReadGateway {
  _FakeMessageReadGateway(this.pages);

  final List<PipelineMessage> pages;
  int? lastSourceChatId;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
    return pages.length;
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    lastSourceChatId = sourceChatId;
    if (fromMessageId == null) {
      return pages.take(1).toList(growable: false);
    }
    return pages.skip(1).toList(growable: false);
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => pages.isEmpty ? null : pages.first;

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    return pages.firstWhere((item) => item.id == messageId);
  }
}

class _DelayedPageMessageReadGateway extends _FakeMessageReadGateway {
  _DelayedPageMessageReadGateway({
    required this.firstPage,
    required this.secondPage,
  }) : super(const <PipelineMessage>[]);

  final List<PipelineMessage> firstPage;
  final List<PipelineMessage> secondPage;
  final Completer<void> _secondPageRelease = Completer<void>();

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    lastSourceChatId = sourceChatId;
    if (fromMessageId == null) {
      return firstPage;
    }
    await _secondPageRelease.future;
    return secondPage;
  }

  void releaseSecondPage() {
    if (!_secondPageRelease.isCompleted) {
      _secondPageRelease.complete();
    }
  }
}

class _FakeMediaGateway implements MediaGateway {
  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }
}

class _SettingsReader implements PipelineSettingsReader {
  _SettingsReader({required this.sourceChatId});

  final int sourceChatId;

  @override
  AppSettings get currentSettings =>
      AppSettings.defaults().updateSourceChatId(sourceChatId);

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => currentSettings.obs;
}

PipelineMessage _message(int id, String title, {int sourceChatId = 888}) {
  return PipelineMessage(
    id: id,
    messageIds: [id],
    sourceChatId: sourceChatId,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}
