import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';

class MessagePreviewBuilder {
  const MessagePreviewBuilder();

  List<PipelineMessage> groupPipelineMessages({
    required List<TdMessageDto> messages,
    required int sourceChatId,
    required MessageFetchDirection direction,
  }) {
    final result = <PipelineMessage>[];
    final shouldReverseGroup = direction == MessageFetchDirection.latestFirst;
    var index = 0;
    while (index < messages.length) {
      final current = messages[index];
      if (!_isGroupedMediaMessage(current)) {
        result.add(
          toPipelineMessage(
            messages: <TdMessageDto>[current],
            sourceChatId: sourceChatId,
          ),
        );
        index++;
        continue;
      }
      final group = <TdMessageDto>[current];
      final albumId = current.mediaAlbumId;
      var next = index + 1;
      while (next < messages.length) {
        final candidate = messages[next];
        if (candidate.mediaAlbumId != albumId ||
            !_isGroupedMediaMessage(candidate)) {
          break;
        }
        group.add(candidate);
        next++;
      }
      final orderedGroup = shouldReverseGroup
          ? group.reversed.toList(growable: false)
          : group;
      result.add(
        toPipelineMessage(messages: orderedGroup, sourceChatId: sourceChatId),
      );
      index = next;
    }
    return result;
  }

  PipelineMessage toPipelineMessage({
    required List<TdMessageDto> messages,
    required int sourceChatId,
  }) {
    final first = messages.first;
    return PipelineMessage(
      id: first.id,
      messageIds: messages.map((item) => item.id).toList(growable: false),
      sourceChatId: sourceChatId,
      preview: _buildPreview(messages),
    );
  }

  bool _isGroupedMediaMessage(TdMessageDto message) {
    final kind = message.content.kind;
    return message.mediaAlbumId != null &&
        (kind == TdMessageContentKind.audio ||
            kind == TdMessageContentKind.photo ||
            kind == TdMessageContentKind.video);
  }

  MessagePreview _buildPreview(List<TdMessageDto> messages) {
    final first = messages.first;
    final primary = mapMessagePreview(first.content);
    if (messages.length == 1) {
      return primary;
    }
    final allAudio = messages.every(
      (item) => item.content.kind == TdMessageContentKind.audio,
    );
    if (!allAudio) {
      return _buildMediaGalleryPreview(messages, primary);
    }
    final tracks = messages
        .map((item) => mapAudioTrackPreview(item.content, messageId: item.id))
        .toList(growable: false);
    return primary.copyWith(
      title: '音频组 (${tracks.length} 条)',
      text: _firstNonEmptyText(messages) ?? primary.text,
      localAudioPath: null,
      audioDurationSeconds: null,
      audioTracks: tracks,
    );
  }

  MessagePreview _buildMediaGalleryPreview(
    List<TdMessageDto> messages,
    MessagePreview primary,
  ) {
    final items = messages
        .map((item) => mapMessagePreview(item.content))
        .expand((preview) => preview.mediaItems)
        .toList(growable: false);
    final containsVideo = items.any((item) => item.kind == MediaItemKind.video);
    final caption = _firstNonEmptyText(messages) ?? primary.text;
    MediaItemPreview? firstVideo;
    for (final item in items) {
      if (item.kind == MediaItemKind.video) {
        firstVideo = item;
        break;
      }
    }
    final firstItem = items.first;
    return primary.copyWith(
      kind: containsVideo ? MessagePreviewKind.video : MessagePreviewKind.photo,
      title: containsVideo
          ? '媒体组 (${items.length} 项)'
          : '图片组 (${items.length} 张)',
      text: caption,
      mediaItems: items,
      localImagePath: firstItem.kind == MediaItemKind.photo
          ? firstItem.previewPath ?? firstItem.fullPath
          : primary.localImagePath,
      localVideoThumbnailPath:
          firstVideo?.previewPath ?? primary.localVideoThumbnailPath,
      localVideoPath: firstVideo?.fullPath ?? primary.localVideoPath,
      videoDurationSeconds:
          firstVideo?.durationSeconds ?? primary.videoDurationSeconds,
    );
  }

  TdFormattedTextDto? _firstNonEmptyText(List<TdMessageDto> messages) {
    for (final item in messages) {
      final text = item.content.text;
      if (text != null && text.text.trim().isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}
