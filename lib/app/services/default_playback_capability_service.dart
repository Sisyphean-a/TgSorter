import 'dart:io';

import 'package:tgsorter/app/services/audio_playback_initializer.dart';
import 'package:tgsorter/app/services/playback_capability_service.dart';
import 'package:tgsorter/app/services/video_playback_initializer.dart';

class PlaybackCapabilityPlatform {
  const PlaybackCapabilityPlatform({
    required this.isAndroid,
    required this.isWindows,
    required this.isLinux,
  });

  final bool isAndroid;
  final bool isWindows;
  final bool isLinux;
}

class DefaultPlaybackCapabilityService implements PlaybackCapabilityService {
  DefaultPlaybackCapabilityService({
    required PlaybackCapabilityPlatform platform,
    AudioBackendInitializer audioInitializer = _defaultAudioInitializer,
    VideoBackendInitializer videoInitializer = _defaultVideoInitializer,
  }) : _platform = platform,
       _audioInitializer = audioInitializer,
       _videoInitializer = videoInitializer;

  factory DefaultPlaybackCapabilityService.detect() {
    return DefaultPlaybackCapabilityService(
      platform: PlaybackCapabilityPlatform(
        isAndroid: Platform.isAndroid,
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
      ),
    );
  }

  final PlaybackCapabilityPlatform _platform;
  final AudioBackendInitializer _audioInitializer;
  final VideoBackendInitializer _videoInitializer;

  @override
  Future<void> initialize() async {
    await initializeAudioPlayback(
      targetPlatform: AudioBackendPlatform(
        isWindows: _platform.isWindows,
        isLinux: _platform.isLinux,
      ),
      initializer: _audioInitializer,
    );
    await initializeVideoPlayback(
      targetPlatform: VideoBackendPlatform(
        isAndroid: _platform.isAndroid,
        isWindows: _platform.isWindows,
      ),
      initializer: _videoInitializer,
    );
  }

  @override
  PlaybackCapabilitySnapshot snapshot() {
    final canInlineVideo = _platform.isAndroid || _platform.isWindows;
    final canInlineAudio =
        _platform.isAndroid || _platform.isWindows || _platform.isLinux;
    return PlaybackCapabilitySnapshot(
      canInlineVideo: canInlineVideo,
      canInlineAudio: canInlineAudio,
      canFullscreenVideo: canInlineVideo,
    );
  }
}

Future<void> _defaultAudioInitializer({
  required bool windows,
  required bool linux,
}) {
  return initializeAudioPlayback(
    targetPlatform: AudioBackendPlatform(isWindows: windows, isLinux: linux),
  );
}

Future<void> _defaultVideoInitializer({
  required bool android,
  required bool iOS,
  required bool macOS,
  required bool windows,
  required bool linux,
  required bool web,
}) {
  return initializeVideoPlayback(
    targetPlatform: VideoBackendPlatform(
      isAndroid: android,
      isWindows: windows,
    ),
  );
}
