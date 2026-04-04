import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_refresh_service.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test(
    'prepareCurrentMedia refreshes current message with prepared payload',
    () async {
      final harness = _PipelineMediaRefreshHarness.videoReady();
      final service = harness.build();

      final refreshed = await service.prepareCurrentMedia(
        sourceChatId: 777,
        messageId: 21,
      );

      expect(refreshed.preview.localVideoPath, '/tmp/video.mp4');
      expect(harness.prepareCalls, 1);
    },
  );

  test('refreshCurrentMedia delegates refresh to message gateway', () async {
    final harness = _PipelineMediaRefreshHarness.videoReady();
    final service = harness.build();

    final refreshed = await service.refreshCurrentMedia(
      sourceChatId: 777,
      messageId: 21,
    );

    expect(refreshed.id, 21);
    expect(harness.refreshCalls, 1);
  });
}

class _PipelineMediaRefreshHarness {
  _PipelineMediaRefreshHarness._({
    required this.mediaGateway,
    required this.messageGateway,
  });

  factory _PipelineMediaRefreshHarness.videoReady() {
    return _PipelineMediaRefreshHarness._(
      mediaGateway: _FakeMediaGateway(),
      messageGateway: _FakeMessageReadGateway(),
    );
  }

  final _FakeMediaGateway mediaGateway;
  final _FakeMessageReadGateway messageGateway;

  int get prepareCalls => mediaGateway.prepareCalls;
  int get refreshCalls => messageGateway.refreshCalls;

  PipelineMediaRefreshService build() {
    return PipelineMediaRefreshService(
      mediaGateway: mediaGateway,
      messageGateway: messageGateway,
    );
  }
}

class _FakeMediaGateway implements MediaGateway {
  int prepareCalls = 0;

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
  }) async {
    prepareCalls++;
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
        localVideoPath: '/tmp/video.mp4',
      ),
    );
  }
}

class _FakeMessageReadGateway implements MessageReadGateway {
  int refreshCalls = 0;

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
  }) async {
    refreshCalls++;
    return PipelineMessage(
      id: messageId,
      messageIds: <int>[messageId],
      sourceChatId: sourceChatId,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'video',
        localVideoPath: '/tmp/video.mp4',
      ),
    );
  }
}
