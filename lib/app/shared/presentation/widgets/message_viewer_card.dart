import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_content.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';

class MessageViewerCard extends StatelessWidget {
  const MessageViewerCard({
    super.key,
    this.message,
    this.vm,
    required this.processing,
    this.videoPreparing = false,
    this.onRequestMediaPlayback,
    this.onMediaAction,
    this.videoControllerInitializer,
    this.isMediaPreparing = _defaultIsMediaPreparing,
  });

  final PipelineMessage? message;
  final MessagePreviewVm? vm;
  final bool processing;
  final bool videoPreparing;
  final Future<void> Function([int? messageId])? onRequestMediaPlayback;
  final Future<void> Function(MediaAction action)? onMediaAction;
  final VideoControllerInitializer? videoControllerInitializer;
  final bool Function(int? messageId) isMediaPreparing;

  static bool _defaultIsMediaPreparing(int? messageId) => false;

  @override
  Widget build(BuildContext context) {
    final resolvedVm = vm ?? _buildLegacyVm();
    return AnimatedContainer(
      duration: AppTokens.quick,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppTokens.surfaceBase,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(
          color: processing ? AppTokens.brandAccent : AppTokens.borderSubtle,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTokens.spaceLg),
              child: MessagePreviewContent(
                vm: resolvedVm,
                onMediaAction: onMediaAction ?? _handleLegacyMediaAction,
                videoControllerInitializer: videoControllerInitializer,
              ),
            ),
          ),
          if (processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  MessagePreviewVm _buildLegacyVm() {
    final data = message;
    if (data == null || data.preview.mediaItems.isEmpty) {
      return MessagePreviewVm(
        content: data,
        media: const MediaSessionVm.empty(),
      );
    }
    final items = <int, MediaItemVm>{
      for (final item in data.preview.mediaItems)
        item.messageId: MediaItemVm(
          messageId: item.messageId,
          kind: item.kind,
          previewPath: item.previewPath,
          playbackPath: item.fullPath,
          previewAvailability: _availabilityFor(item.previewPath),
          playbackAvailability: isMediaPreparing(item.messageId)
              ? MediaAvailability.preparing
              : _availabilityFor(item.fullPath),
          canPlay: item.kind != MediaItemKind.video || item.fullPath != null,
        ),
    };
    final activeItemMessageId = data.preview.mediaItems.first.messageId;
    return MessagePreviewVm(
      content: data,
      media: MediaSessionVm(
        groupMessageId: data.id,
        activeItemMessageId: activeItemMessageId,
        requestState: videoPreparing
            ? MediaRequestState.preparing
            : MediaRequestState.idle,
        items: Map<int, MediaItemVm>.unmodifiable(items),
      ),
    );
  }

  Future<void> _handleLegacyMediaAction(MediaAction action) async {
    if (action case OpenInApp(:final messageId)) {
      await onRequestMediaPlayback?.call(messageId);
    }
  }

  MediaAvailability _availabilityFor(String? path) {
    return path != null && path.isNotEmpty
        ? MediaAvailability.ready
        : MediaAvailability.missing;
  }
}
