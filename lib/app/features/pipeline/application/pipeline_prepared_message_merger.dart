import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

PipelineMessage mergePreparedMessage(
  PipelineMessage current,
  PipelineMessage prepared,
) {
  if (current.preview.mediaItems.isNotEmpty) {
    final preparedItem = prepared.preview.mediaItems.isEmpty
        ? null
        : prepared.preview.mediaItems.first;
    if (preparedItem != null) {
      final items = current.preview.mediaItems
          .map((item) {
            if (item.messageId != prepared.id) {
              return item;
            }
            return item.copyWith(
              previewPath: preparedItem.previewPath,
              fullPath: preparedItem.fullPath,
              durationSeconds: preparedItem.durationSeconds,
              caption: preparedItem.caption,
            );
          })
          .toList(growable: false);
      final preview = current.preview.copyWith(
        mediaItems: items,
        localVideoPath:
            current.preview.localVideoPath ?? prepared.preview.localVideoPath,
        localVideoThumbnailPath:
            current.preview.localVideoThumbnailPath ??
            prepared.preview.localVideoThumbnailPath,
        localImagePath:
            current.preview.localImagePath ?? prepared.preview.localImagePath,
      );
      return current.copyWith(preview: preview);
    }
  }
  if (current.preview.kind != MessagePreviewKind.audio ||
      current.preview.audioTracks.length <= 1) {
    return prepared;
  }
  final tracks = current.preview.audioTracks
      .map((track) {
        if (track.messageId != prepared.id) {
          return track;
        }
        final preview = prepared.preview;
        return track.copyWith(
          localAudioPath: preview.localAudioPath,
          audioDurationSeconds: preview.audioDurationSeconds,
          title: preview.title,
          subtitle: preview.subtitle,
        );
      })
      .toList(growable: false);
  return current.copyWith(
    preview: current.preview.copyWith(audioTracks: tracks),
  );
}
