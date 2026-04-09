import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class MediaSessionProjector {
  const MediaSessionProjector();

  MediaSessionState project(
    PipelineMessage? message, {
    MediaSessionState? currentSession,
    int? activeItemMessageId,
    Set<int> preparingItemIds = const <int>{},
  }) {
    if (message == null) {
      return const MediaSessionState.empty();
    }
    final base = MediaSessionState.fromMessage(
      message,
      activeItemMessageId:
          activeItemMessageId ?? currentSession?.activeItemMessageId,
    );
    if (base.items.isEmpty) {
      return base;
    }
    final items = base.items.map((messageId, item) {
      if (!preparingItemIds.contains(messageId)) {
        return MapEntry(messageId, item);
      }
      return MapEntry(
        messageId,
        item.copyWith(playbackAvailability: MediaAvailability.preparing),
      );
    });
    final activeItem = items[base.activeItemMessageId];
    final requestState = preparingItemIds.isNotEmpty
        ? MediaRequestState.preparing
        : _deriveRequestState(activeItem);
    return base.copyWith(
      items: Map<int, MediaItemSessionState>.unmodifiable(items),
      requestState: requestState,
    );
  }

  MediaRequestState _deriveRequestState(MediaItemSessionState? activeItem) {
    if (activeItem == null) {
      return MediaRequestState.idle;
    }
    if (activeItem.playbackAvailability == MediaAvailability.ready ||
        activeItem.previewAvailability == MediaAvailability.ready) {
      return MediaRequestState.ready;
    }
    return MediaRequestState.idle;
  }
}
