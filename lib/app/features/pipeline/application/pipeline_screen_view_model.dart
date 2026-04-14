import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

sealed class MediaAction {
  const MediaAction();
}

class OpenInApp extends MediaAction {
  const OpenInApp({required this.messageId});

  final int messageId;
}

class OpenExternally extends MediaAction {
  const OpenExternally({required this.messageId});

  final int messageId;
}

class RevealInFolder extends MediaAction {
  const RevealInFolder({required this.messageId});

  final int messageId;
}

class CopyPath extends MediaAction {
  const CopyPath({required this.messageId});

  final int messageId;
}

class OpenLink extends MediaAction {
  const OpenLink({required this.url});

  final Uri url;
}

class PipelineScreenVm {
  const PipelineScreenVm({
    required this.message,
    required this.navigation,
    required this.workflow,
  });

  final MessagePreviewVm message;
  final NavigationVm navigation;
  final WorkflowVm workflow;
}

class MessagePreviewVm {
  const MessagePreviewVm({required this.content, required this.media});

  final PipelineMessage? content;
  final MediaSessionVm media;
}

class NavigationVm {
  const NavigationVm({
    required this.canShowPrevious,
    required this.canShowNext,
  });

  final bool canShowPrevious;
  final bool canShowNext;
}

class WorkflowVm {
  const WorkflowVm({required this.processingOverlay, required this.online});

  final bool processingOverlay;
  final bool online;
}

class MediaSessionVm {
  const MediaSessionVm({
    this.groupMessageId,
    this.activeItemMessageId,
    this.requestState = MediaRequestState.idle,
    this.items = const <int, MediaItemVm>{},
  });

  const MediaSessionVm.empty()
    : groupMessageId = null,
      activeItemMessageId = null,
      requestState = MediaRequestState.idle,
      items = const <int, MediaItemVm>{};

  final int? groupMessageId;
  final int? activeItemMessageId;
  final MediaRequestState requestState;
  final Map<int, MediaItemVm> items;

  MediaItemVm? get activeItem => items[activeItemMessageId];

  factory MediaSessionVm.fromState(MediaSessionState? state) {
    if (state == null || state.items.isEmpty) {
      return const MediaSessionVm.empty();
    }
    final items = state.items.map((messageId, item) {
      return MapEntry(
        messageId,
        MediaItemVm(
          messageId: item.messageId,
          kind: item.kind,
          previewPath: item.previewPath,
          playbackPath: item.playbackPath,
          previewAvailability: item.previewAvailability,
          playbackAvailability: item.playbackAvailability,
          playbackState: item.playbackState,
          canPlay: item.playbackAvailability == MediaAvailability.ready,
          errorMessage: item.errorMessage,
        ),
      );
    });
    return MediaSessionVm(
      groupMessageId: state.groupMessageId,
      activeItemMessageId: state.activeItemMessageId,
      requestState: state.requestState,
      items: Map<int, MediaItemVm>.unmodifiable(items),
    );
  }
}

class MediaItemVm {
  const MediaItemVm({
    required this.messageId,
    required this.kind,
    this.previewPath,
    this.playbackPath,
    this.previewAvailability = MediaAvailability.missing,
    this.playbackAvailability = MediaAvailability.missing,
    this.playbackState = PlaybackState.idle,
    this.canPlay = false,
    this.errorMessage,
  });

  final int messageId;
  final MediaItemKind kind;
  final String? previewPath;
  final String? playbackPath;
  final MediaAvailability previewAvailability;
  final MediaAvailability playbackAvailability;
  final PlaybackState playbackState;
  final bool canPlay;
  final String? errorMessage;

  bool get preparing => playbackAvailability == MediaAvailability.preparing;
  bool get failed =>
      errorMessage != null ||
      previewAvailability == MediaAvailability.failed ||
      playbackAvailability == MediaAvailability.failed;
}
