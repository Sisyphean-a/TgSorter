import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_audio.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_link.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_media.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_text.dart';

class MessagePreviewContent extends StatelessWidget {
  const MessagePreviewContent({
    super.key,
    required this.message,
    required this.videoPreparing,
    required this.onRequestMediaPlayback,
    required this.videoControllerInitializer,
  });

  final PipelineMessage? message;
  final bool videoPreparing;
  final Future<void> Function([int? messageId]) onRequestMediaPlayback;
  final VideoControllerInitializer? videoControllerInitializer;

  @override
  Widget build(BuildContext context) {
    final data = message;
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
    if (preview.kind == MessagePreviewKind.photo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewMedia(
            items: mediaItems,
            preparing: videoPreparing,
            onRequestPlayback: onRequestMediaPlayback,
            controllerInitializer: videoControllerInitializer,
            fallbackImagePath: preview.localImagePath,
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
            preparing: videoPreparing,
            onRequestPlayback: onRequestMediaPlayback,
            controllerInitializer: videoControllerInitializer,
            preferVideoFallback: true,
            fallbackVideoPath: preview.localVideoPath,
            fallbackThumbnailPath: preview.localVideoThumbnailPath,
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
            preparing: videoPreparing,
            onRequestPlayback: onRequestMediaPlayback,
            tracks: preview.audioTracks,
          ),
          const SizedBox(height: 12),
          if (preview.subtitle case final text? when text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                text,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (preview.audioDurationSeconds != null)
            PreviewMetaText(
              text:
                  '时长 ${formatPreviewDuration(preview.audioDurationSeconds!)}',
            ),
          const SizedBox(height: 8),
          Text(
            preview.title,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
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
