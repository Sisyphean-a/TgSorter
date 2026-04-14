import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_projector.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_session_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test(
    'requestPlayback selects target item and marks session preparing',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = _groupVideoMessage();
      final legacyController = _RecordingLegacyMediaController(state);
      final controller = PipelineMediaSessionController(
        state: state,
        legacyController: legacyController,
        projector: const MediaSessionProjector(),
      );

      await controller.requestPlayback(22);

      expect(legacyController.prepareCalls, 1);
      expect(state.mediaSession.value?.activeItemMessageId, 22);
      expect(
        state.mediaSession.value?.requestState,
        MediaRequestState.preparing,
      );
    },
  );

  test('message refresh preserves active grouped item selection', () async {
    final state = PipelineRuntimeState();
    state.currentMessage.value = _groupVideoMessage();
    final controller = PipelineMediaSessionController(
      state: state,
      legacyController: _RecordingLegacyMediaController(state),
      projector: const MediaSessionProjector(),
    );

    controller.selectItem(22);
    state.currentMessage.value = PipelineMessage(
      id: 21,
      messageIds: const <int>[21, 22],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'album',
        mediaItems: [
          MediaItemPreview(
            messageId: 21,
            kind: MediaItemKind.video,
            previewPath: 'C:/thumb-1.jpg',
          ),
          MediaItemPreview(
            messageId: 22,
            kind: MediaItemKind.video,
            previewPath: 'C:/thumb-2.jpg',
            fullPath: 'C:/video-2.mp4',
          ),
        ],
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(state.mediaSession.value?.activeItemMessageId, 22);
    expect(
      state.mediaSession.value?.items[22]?.playbackAvailability,
      MediaAvailability.ready,
    );
  });

  test('requestPlayback marks single video session as preparing', () async {
    final state = PipelineRuntimeState();
    state.currentMessage.value = PipelineMessage(
      id: 31,
      messageIds: const <int>[31],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'single-video',
      ),
    );
    final controller = PipelineMediaSessionController(
      state: state,
      legacyController: _RecordingLegacyMediaController(state),
      projector: const MediaSessionProjector(),
    );

    await controller.requestPlayback(31);

    expect(state.mediaSession.value?.activeItemMessageId, 31);
    expect(state.mediaSession.value?.requestState, MediaRequestState.preparing);
    expect(
      state.mediaSession.value?.items[31]?.playbackAvailability,
      MediaAvailability.preparing,
    );
  });

  test(
    'runtime media failure projects failed item state into session',
    () async {
      final state = PipelineRuntimeState();
      state.currentMessage.value = _groupVideoMessage();
      final controller = PipelineMediaSessionController(
        state: state,
        legacyController: _RecordingLegacyMediaController(state),
        projector: const MediaSessionProjector(),
      );

      controller.selectItem(22);
      state.mediaFailureMessages[22] = '视频下载失败';
      await Future<void>.delayed(Duration.zero);

      expect(state.mediaSession.value?.activeItemMessageId, 22);
      expect(state.mediaSession.value?.requestState, MediaRequestState.failed);
      expect(
        state.mediaSession.value?.items[22]?.playbackAvailability,
        MediaAvailability.failed,
      );
      expect(state.mediaSession.value?.items[22]?.errorMessage, '视频下载失败');
    },
  );
}

PipelineMessage _groupVideoMessage() {
  return PipelineMessage(
    id: 21,
    messageIds: const <int>[21, 22],
    sourceChatId: 8888,
    preview: const MessagePreview(
      kind: MessagePreviewKind.video,
      title: 'album',
      mediaItems: [
        MediaItemPreview(messageId: 21, kind: MediaItemKind.video),
        MediaItemPreview(messageId: 22, kind: MediaItemKind.video),
      ],
    ),
  );
}

class _RecordingLegacyMediaController implements PipelineLegacyMediaController {
  _RecordingLegacyMediaController(this.state);

  final PipelineRuntimeState state;
  int prepareCalls = 0;

  @override
  bool isPreparingMessageId(int? messageId) =>
      state.preparingMessageIds.contains(messageId);

  @override
  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    prepareCalls++;
    state.preparingMessageIds
      ..clear()
      ..add(targetMessageId ?? 21);
    state.videoPreparing.value = true;
  }

  @override
  Future<void> refreshCurrentMediaIfNeeded() async {}

  @override
  void stop() {
    state.preparingMessageIds.clear();
    state.videoPreparing.value = false;
  }
}
