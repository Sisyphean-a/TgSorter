class PlaybackCapabilitySnapshot {
  const PlaybackCapabilitySnapshot({
    required this.canInlineVideo,
    required this.canInlineAudio,
    required this.canFullscreenVideo,
  });

  final bool canInlineVideo;
  final bool canInlineAudio;
  final bool canFullscreenVideo;
}

abstract interface class PlaybackCapabilityService {
  Future<void> initialize();

  PlaybackCapabilitySnapshot snapshot();
}
