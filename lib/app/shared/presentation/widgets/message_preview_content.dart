import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
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
      return _buildEmptyState();
    }
    return _buildContent(data);
  }

  Widget _buildEmptyState() {
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

  Widget _buildContent(PipelineMessage data) {
    final preview = data.preview;
    final linkCard = preview.linkCard;
    if (preview.kind == MessagePreviewKind.photo) {
      return _buildPhotoContent(data);
    }
    if (preview.kind == MessagePreviewKind.video) {
      return _buildVideoContent(data);
    }
    if (preview.kind == MessagePreviewKind.audio) {
      return _buildAudioContent(data);
    }
    if (linkCard != null) {
      return MessagePreviewLinkCard(link: linkCard);
    }
    return MessagePreviewText(
      text: preview.text,
      fallbackText: preview.title,
      fontSize: 18,
    );
  }

  Widget _buildPhotoContent(PipelineMessage data) {
    final preview = data.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MessagePreviewMedia(
          items: preview.mediaItems,
          preparing: _isPreparing,
          onRequestPlayback: ([messageId]) => _openMedia(data, messageId),
          controllerInitializer: videoControllerInitializer,
          fallbackImagePath: preview.localImagePath,
          isMediaPreparing: _isMediaPreparing,
          errorForMedia: _mediaError,
        ),
        const SizedBox(height: 12),
        _buildText(preview, fontSize: 16),
      ],
    );
  }

  Widget _buildVideoContent(PipelineMessage data) {
    final preview = data.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MessagePreviewMedia(
          items: preview.mediaItems,
          preparing: _isPreparing,
          onRequestPlayback: ([messageId]) => _openMedia(data, messageId),
          controllerInitializer: videoControllerInitializer,
          preferVideoFallback: true,
          fallbackVideoPath: preview.localVideoPath,
          fallbackThumbnailPath: preview.localVideoThumbnailPath,
          isMediaPreparing: _isMediaPreparing,
          errorForMedia: _mediaError,
        ),
        _buildVideoSpacing(preview),
        _buildText(preview, fontSize: 16),
      ],
    );
  }

  Widget _buildAudioContent(PipelineMessage data) {
    final preview = data.preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MessagePreviewAudio(
          audioPath: preview.localAudioPath,
          preparing: _isPreparing,
          onRequestPlayback: ([messageId]) => _openMedia(data, messageId),
          tracks: preview.audioTracks,
          isPreparingTrack: _isMediaPreparing,
          errorForTrack: _mediaError,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildVideoSpacing(MessagePreview preview) {
    if (preview.mediaItems.isNotEmpty) {
      return const SizedBox(height: 12);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (preview.videoDurationSeconds != null)
          PreviewMetaText(
            text: '时长 ${formatPreviewDuration(preview.videoDurationSeconds!)}',
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildText(MessagePreview preview, {required double fontSize}) {
    return MessagePreviewText(
      text: preview.text,
      fallbackText: preview.title,
      fontSize: fontSize,
    );
  }

  bool get _isPreparing {
    return vm.media.requestState == MediaRequestState.preparing;
  }

  bool _isMediaPreparing(int? messageId) {
    return vm.media.items[messageId]?.preparing ?? _isPreparing;
  }

  String? _mediaError(int? messageId) {
    return vm.media.items[messageId]?.errorMessage;
  }

  Future<void> _openMedia(PipelineMessage data, int? messageId) async {
    await onMediaAction(OpenInApp(messageId: messageId ?? data.id));
  }
}
