import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_audio.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_link.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_media.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_text.dart';

class MessagePreviewContent extends StatelessWidget {
  const MessagePreviewContent({
    super.key,
    required this.vm,
    required this.onMediaAction,
    required this.videoControllerInitializer,
  });

  final MessagePreviewVm vm;
  final Future<void> Function(MediaAction action) onMediaAction;
  final VideoControllerInitializer? videoControllerInitializer;

  @override
  Widget build(BuildContext context) {
    final data = vm.content;
    if (data == null) {
      return const Column(
        key: Key('message-preview-empty-state'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 100),
          Icon(Icons.check_circle, color: Colors.green, size: 96),
          SizedBox(height: 16),
          Text('暂无消息', style: TextStyle(fontSize: 18)),
        ],
      );
    }

    final preview = data.preview;
    final linkCard = preview.linkCard;
    final mediaItems = preview.mediaItems;
    final mediaSession = vm.media;
    final preparing = mediaSession.requestState == MediaRequestState.preparing;
    if (preview.kind == MessagePreviewKind.photo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewMedia(
            items: mediaItems,
            preparing: preparing,
            onRequestPlayback: ([messageId]) async {
              await onMediaAction(OpenInApp(messageId: messageId ?? data.id));
            },
            controllerInitializer: videoControllerInitializer,
            fallbackImagePath: preview.localImagePath,
            isMediaPreparing: (messageId) =>
                mediaSession.items[messageId]?.preparing ?? preparing,
          ),
          const SizedBox(height: 12),
          MessagePreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 16,
          ),
        ],
      );
    }

    if (preview.kind == MessagePreviewKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewMedia(
            items: mediaItems,
            preparing: preparing,
            onRequestPlayback: ([messageId]) async {
              await onMediaAction(OpenInApp(messageId: messageId ?? data.id));
            },
            controllerInitializer: videoControllerInitializer,
            preferVideoFallback: true,
            fallbackVideoPath: preview.localVideoPath,
            fallbackThumbnailPath: preview.localVideoThumbnailPath,
            isMediaPreparing: (messageId) =>
                mediaSession.items[messageId]?.preparing ?? preparing,
          ),
          if (mediaItems.isEmpty) ...[
            const SizedBox(height: 12),
            if (preview.videoDurationSeconds != null)
              PreviewMetaText(
                text:
                    '时长 ${formatPreviewDuration(preview.videoDurationSeconds!)}',
              ),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 12),
          MessagePreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 16,
          ),
        ],
      );
    }

    if (preview.kind == MessagePreviewKind.audio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewAudio(
            audioPath: preview.localAudioPath,
            preparing: preparing,
            onRequestPlayback: ([messageId]) async {
              await onMediaAction(OpenInApp(messageId: messageId ?? data.id));
            },
            tracks: preview.audioTracks,
            isPreparingTrack: (messageId) =>
                mediaSession.items[messageId]?.preparing ?? preparing,
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    if (linkCard != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewLinkCard(link: linkCard),
          const SizedBox(height: 12),
          MessagePreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 18,
          ),
        ],
      );
    }

    return MessagePreviewText(
      text: preview.text,
      fallbackText: preview.title,
      fontSize: 18,
    );
  }
}
