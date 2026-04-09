import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

enum MediaRequestState { idle, preparing, ready, failed }

enum MediaAvailability { missing, preparing, ready, unavailable, failed }

enum PlaybackState { idle, loading, playing, paused }

class MediaItemSessionState {
  const MediaItemSessionState({
    required this.messageId,
    required this.kind,
    required this.previewAvailability,
    required this.playbackAvailability,
    required this.playbackState,
    this.previewPath,
    this.playbackPath,
  });

  final int messageId;
  final MediaItemKind kind;
  final MediaAvailability previewAvailability;
  final MediaAvailability playbackAvailability;
  final PlaybackState playbackState;
  final String? previewPath;
  final String? playbackPath;

  MediaItemSessionState copyWith({
    int? messageId,
    MediaItemKind? kind,
    MediaAvailability? previewAvailability,
    MediaAvailability? playbackAvailability,
    PlaybackState? playbackState,
    String? previewPath,
    String? playbackPath,
  }) {
    return MediaItemSessionState(
      messageId: messageId ?? this.messageId,
      kind: kind ?? this.kind,
      previewAvailability: previewAvailability ?? this.previewAvailability,
      playbackAvailability: playbackAvailability ?? this.playbackAvailability,
      playbackState: playbackState ?? this.playbackState,
      previewPath: previewPath ?? this.previewPath,
      playbackPath: playbackPath ?? this.playbackPath,
    );
  }
}

class MediaSessionState {
  const MediaSessionState({
    required this.groupMessageId,
    required this.activeItemMessageId,
    required this.requestState,
    required this.items,
  });

  const MediaSessionState.empty()
    : groupMessageId = null,
      activeItemMessageId = null,
      requestState = MediaRequestState.idle,
      items = const <int, MediaItemSessionState>{};

  final int? groupMessageId;
  final int? activeItemMessageId;
  final MediaRequestState requestState;
  final Map<int, MediaItemSessionState> items;

  MediaSessionState copyWith({
    int? groupMessageId,
    int? activeItemMessageId,
    MediaRequestState? requestState,
    Map<int, MediaItemSessionState>? items,
  }) {
    return MediaSessionState(
      groupMessageId: groupMessageId ?? this.groupMessageId,
      activeItemMessageId: activeItemMessageId ?? this.activeItemMessageId,
      requestState: requestState ?? this.requestState,
      items: items ?? this.items,
    );
  }

  factory MediaSessionState.fromMessage(
    PipelineMessage message, {
    int? activeItemMessageId,
  }) {
    final states = <int, MediaItemSessionState>{};
    final preview = message.preview;
    if (preview.mediaItems.isNotEmpty) {
      for (final item in preview.mediaItems) {
        states[item.messageId] = MediaItemSessionState(
          messageId: item.messageId,
          kind: item.kind,
          previewAvailability: _availabilityFor(
            preferredPath: item.previewPath,
            fallbackPath: item.fullPath,
          ),
          playbackAvailability: _availabilityFor(preferredPath: item.fullPath),
          playbackState: PlaybackState.idle,
          previewPath: item.previewPath,
          playbackPath: item.fullPath,
        );
      }
    } else {
      _appendStandaloneStates(message, states);
    }
    if (states.isEmpty) {
      return const MediaSessionState.empty();
    }
    final firstItemMessageId = states.keys.first;
    final resolvedActiveItemId = states.containsKey(activeItemMessageId)
        ? activeItemMessageId
        : firstItemMessageId;
    return MediaSessionState(
      groupMessageId: message.id,
      activeItemMessageId: resolvedActiveItemId,
      requestState: MediaRequestState.idle,
      items: Map<int, MediaItemSessionState>.unmodifiable(states),
    );
  }

  static MediaAvailability _availabilityFor({
    String? preferredPath,
    String? fallbackPath,
  }) {
    final path = preferredPath ?? fallbackPath;
    return path != null && path.isNotEmpty
        ? MediaAvailability.ready
        : MediaAvailability.missing;
  }

  static void _appendStandaloneStates(
    PipelineMessage message,
    Map<int, MediaItemSessionState> states,
  ) {
    final preview = message.preview;
    if (preview.kind == MessagePreviewKind.video) {
      states[message.id] = MediaItemSessionState(
        messageId: message.id,
        kind: MediaItemKind.video,
        previewAvailability: _availabilityFor(
          preferredPath: preview.localVideoThumbnailPath,
          fallbackPath: preview.localVideoPath,
        ),
        playbackAvailability: _availabilityFor(
          preferredPath: preview.localVideoPath,
        ),
        playbackState: PlaybackState.idle,
        previewPath: preview.localVideoThumbnailPath,
        playbackPath: preview.localVideoPath,
      );
      return;
    }
    if (preview.kind != MessagePreviewKind.audio) {
      return;
    }
    if (preview.audioTracks.isEmpty) {
      states[message.id] = MediaItemSessionState(
        messageId: message.id,
        kind: MediaItemKind.audio,
        previewAvailability: _availabilityFor(
          preferredPath: preview.localAudioPath,
        ),
        playbackAvailability: _availabilityFor(
          preferredPath: preview.localAudioPath,
        ),
        playbackState: PlaybackState.idle,
        playbackPath: preview.localAudioPath,
      );
      return;
    }
    for (final track in preview.audioTracks) {
      states[track.messageId] = MediaItemSessionState(
        messageId: track.messageId,
        kind: MediaItemKind.audio,
        previewAvailability: _availabilityFor(
          preferredPath: track.localAudioPath,
        ),
        playbackAvailability: _availabilityFor(
          preferredPath: track.localAudioPath,
        ),
        playbackState: PlaybackState.idle,
        playbackPath: track.localAudioPath,
      );
    }
  }
}
