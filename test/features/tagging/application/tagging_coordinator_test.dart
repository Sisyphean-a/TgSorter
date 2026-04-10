import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';

void main() {
  group('TaggingCoordinator', () {
    test('fetchNext uses tag source chat', () async {
      final messages = _FakeMessageReadGateway([_message(1, 'first')]);
      final coordinator = _buildCoordinator(messages: messages);

      await coordinator.fetchNext();

      expect(messages.lastSourceChatId, -1001);
      expect(coordinator.currentMessage.value?.id, 1);
    });

    test('applyTag replaces current message with edited result', () async {
      final tagging = _FakeTaggingGateway(
        result: ApplyTagResult(
          message: _message(1, 'first #摄影'),
          changed: true,
        ),
      );
      final coordinator = _buildCoordinator(tagging: tagging);
      coordinator.isOnline.value = true;
      await coordinator.fetchNext();

      await coordinator.applyTag('摄影');

      expect(tagging.lastSourceChatId, -1001);
      expect(tagging.lastMessageIds, [1]);
      expect(coordinator.currentMessage.value?.preview.title, 'first #摄影');
    });

    test('applyTag failure reports error and keeps current message', () async {
      final errors = AppErrorController();
      final coordinator = _buildCoordinator(
        errors: errors,
        tagging: _FakeTaggingGateway(error: StateError('edit failed')),
      );
      coordinator.isOnline.value = true;
      await coordinator.fetchNext();

      await coordinator.applyTag('摄影');

      expect(coordinator.currentMessage.value?.preview.title, 'first');
      expect(errors.currentError.value, contains('edit failed'));
    });
  });
}

TaggingCoordinator _buildCoordinator({
  _FakeMessageReadGateway? messages,
  _FakeTaggingGateway? tagging,
  AppErrorController? errors,
}) {
  return TaggingCoordinator(
    messageReadGateway:
        messages ?? _FakeMessageReadGateway([_message(1, 'first')]),
    mediaGateway: _FakeMediaGateway(),
    taggingGateway: tagging ?? _FakeTaggingGateway(),
    settingsReader: _SettingsReader(),
    errorController: errors ?? AppErrorController(),
  );
}

class _FakeTaggingGateway implements TaggingGateway {
  _FakeTaggingGateway({this.result, this.error});

  final ApplyTagResult? result;
  final Object? error;
  int? lastSourceChatId;
  List<int>? lastMessageIds;

  @override
  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  }) async {
    lastSourceChatId = sourceChatId;
    lastMessageIds = messageIds;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result ??
        ApplyTagResult(message: _message(1, 'first'), changed: false);
  }
}

class _FakeMessageReadGateway implements MessageReadGateway {
  _FakeMessageReadGateway(this.messages);

  final List<PipelineMessage> messages;
  int? lastSourceChatId;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
    return messages.length;
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    lastSourceChatId = sourceChatId;
    return messages;
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => messages.isEmpty ? null : messages.first;

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async => messages.first;
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

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }
}

class _SettingsReader implements PipelineSettingsReader {
  final settings = AppSettings.defaults().copyWith(tagSourceChatId: -1001);

  @override
  AppSettings get currentSettings => settings;

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => settings.obs;
}

PipelineMessage _message(int id, String title) {
  return PipelineMessage(
    id: id,
    messageIds: [id],
    sourceChatId: -1001,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: title),
  );
}
