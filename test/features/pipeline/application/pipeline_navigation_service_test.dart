import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_navigation_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_runtime_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  test(
    'showNext moves current index and exposes next cached message',
    () async {
      final state = PipelineRuntimeState();
      final service = PipelineNavigationService(state: state);
      final first = fakePipelineMessage(id: 101);
      final second = fakePipelineMessage(id: 102);

      service.replaceMessages(<PipelineMessage>[first, second]);

      expect(state.currentMessage.value?.id, 101);
      await service.showNext();
      expect(state.currentMessage.value?.id, 102);
      expect(state.navigation.value.canShowPrevious, isTrue);
      expect(state.canShowPrevious.value, isTrue);
    },
  );

  test(
    'appendUniqueMessages appends only unknown ids and updates nav state',
    () {
      final state = PipelineRuntimeState();
      final service = PipelineNavigationService(state: state);
      final first = fakePipelineMessage(id: 101);
      final duplicate = fakePipelineMessage(id: 101);
      final second = fakePipelineMessage(id: 102);

      service.replaceMessages(<PipelineMessage>[first]);
      service.appendUniqueMessages(<PipelineMessage>[duplicate, second]);

      expect(state.cache.map((item) => item.id), <int>[101, 102]);
      expect(state.currentMessage.value?.id, 101);
      expect(state.navigation.value.next, NextAvailability.cached);
      expect(state.canShowNext.value, isTrue);
    },
  );

  test('replaceMessages projects media session from current media message', () {
    final state = PipelineRuntimeState();
    final service = PipelineNavigationService(state: state);
    final mediaMessage = PipelineMessage(
      id: 201,
      messageIds: const <int>[201, 202],
      sourceChatId: 8888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.video,
        title: 'album',
        mediaItems: [
          MediaItemPreview(
            messageId: 201,
            kind: MediaItemKind.video,
            previewPath: 'C:/thumb.jpg',
          ),
          MediaItemPreview(messageId: 202, kind: MediaItemKind.video),
        ],
      ),
    );

    service.replaceMessages(<PipelineMessage>[mediaMessage]);

    expect(state.mediaSession.value?.groupMessageId, 201);
    expect(state.mediaSession.value?.activeItemMessageId, 201);
  });

  test(
    'removeCurrentAndSync keeps current index valid and updates current',
    () async {
      final state = PipelineRuntimeState();
      final service = PipelineNavigationService(state: state);
      final first = fakePipelineMessage(id: 101);
      final second = fakePipelineMessage(id: 102);

      service.replaceMessages(<PipelineMessage>[first, second]);
      await service.showNext();
      service.removeCurrentAndSync();

      expect(state.cache.map((item) => item.id), <int>[101]);
      expect(state.currentMessage.value?.id, 101);
      expect(state.navigation.value.canShowPrevious, isFalse);
      expect(state.navigation.value.next, NextAvailability.none);
    },
  );

  test('syncNavigationState distinguishes cached fetchable and none', () {
    final state = PipelineRuntimeState();
    final service = PipelineNavigationService(state: state);
    final first = fakePipelineMessage(id: 101);
    final second = fakePipelineMessage(id: 102);

    state.remainingCount.value = 5;
    service.replaceMessages(<PipelineMessage>[first]);

    expect(state.currentMessage.value?.id, 101);
    expect(state.navigation.value.canShowPrevious, isFalse);
    expect(state.navigation.value.next, NextAvailability.fetchable);

    service.appendUniqueMessages(<PipelineMessage>[second]);
    expect(state.navigation.value.next, NextAvailability.cached);

    state.remainingCount.value = 2;
    service.syncNavigationState();
    expect(state.navigation.value.next, NextAvailability.cached);
  });
}

PipelineMessage fakePipelineMessage({required int id}) {
  return PipelineMessage(
    id: id,
    messageIds: <int>[id],
    sourceChatId: 8888,
    preview: MessagePreview(kind: MessagePreviewKind.text, title: '$id'),
  );
}
