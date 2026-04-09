import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_media_preparation_service.dart';
import 'package:tgsorter/app/services/media_preparation_service.dart';

void main() {
  test(
    'preparePlayback delegates to structured media preparation service',
    () async {
      final mediaPreparation = _FakeMediaPreparationService();
      final service = PipelineMediaPreparationService(
        mediaPreparation: mediaPreparation,
      );

      final result = await service.preparePlayback(
        handle: const MediaHandle(
          sourceChatId: 777,
          itemMessageId: 21,
          kind: MediaItemKind.video,
        ),
      );

      expect(result.status, MediaPreparationStatus.ready);
      expect(result.playbackPath, '/tmp/video.mp4');
      expect(mediaPreparation.preparePlaybackCalls, 1);
    },
  );

  test(
    'preparePreview delegates to structured media preparation service',
    () async {
      final mediaPreparation = _FakeMediaPreparationService();
      final service = PipelineMediaPreparationService(
        mediaPreparation: mediaPreparation,
      );

      final result = await service.preparePreview(
        handle: const MediaHandle(
          sourceChatId: 777,
          itemMessageId: 21,
          kind: MediaItemKind.video,
        ),
      );

      expect(result.status, MediaPreparationStatus.ready);
      expect(result.previewPath, '/tmp/thumb.jpg');
      expect(mediaPreparation.preparePreviewCalls, 1);
    },
  );
}

class _FakeMediaPreparationService implements MediaPreparationService {
  int preparePlaybackCalls = 0;
  int preparePreviewCalls = 0;

  @override
  Future<MediaPreparationResult> preparePlayback(MediaHandle handle) async {
    preparePlaybackCalls++;
    return const MediaPreparationResult(
      status: MediaPreparationStatus.ready,
      playbackPath: '/tmp/video.mp4',
    );
  }

  @override
  Future<MediaPreparationResult> preparePreview(MediaHandle handle) async {
    preparePreviewCalls++;
    return const MediaPreparationResult(
      status: MediaPreparationStatus.ready,
      previewPath: '/tmp/thumb.jpg',
    );
  }
}
