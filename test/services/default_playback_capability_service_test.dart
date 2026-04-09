import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/audio_playback_initializer.dart';
import 'package:tgsorter/app/services/default_playback_capability_service.dart';
import 'package:tgsorter/app/services/video_playback_initializer.dart';

void main() {
  test(
    'initialize configures audio and video backends from one service',
    () async {
      AudioBackendInitCall? audioCall;
      VideoBackendInitCall? videoCall;
      final service = DefaultPlaybackCapabilityService(
        platform: const PlaybackCapabilityPlatform(
          isAndroid: true,
          isWindows: false,
          isLinux: false,
        ),
        audioInitializer: ({required bool windows, required bool linux}) async {
          audioCall = AudioBackendInitCall(windows: windows, linux: linux);
        },
        videoInitializer:
            ({
              required bool android,
              required bool iOS,
              required bool macOS,
              required bool windows,
              required bool linux,
              required bool web,
            }) async {
              videoCall = VideoBackendInitCall(
                android: android,
                iOS: iOS,
                macOS: macOS,
                windows: windows,
                linux: linux,
              );
            },
      );

      await service.initialize();

      expect(audioCall?.windows, isFalse);
      expect(audioCall?.linux, isFalse);
      expect(videoCall?.android, isTrue);
      expect(videoCall?.windows, isFalse);
    },
  );

  test('snapshot centralizes playback support', () {
    final service = DefaultPlaybackCapabilityService(
      platform: const PlaybackCapabilityPlatform(
        isAndroid: false,
        isWindows: true,
        isLinux: false,
      ),
    );

    final snapshot = service.snapshot();

    expect(snapshot.canInlineVideo, isTrue);
    expect(snapshot.canInlineAudio, isTrue);
    expect(snapshot.canFullscreenVideo, isTrue);
  });

  test('snapshot keeps linux limited to audio-only playback', () {
    final service = DefaultPlaybackCapabilityService(
      platform: const PlaybackCapabilityPlatform(
        isAndroid: false,
        isWindows: false,
        isLinux: true,
      ),
    );

    final snapshot = service.snapshot();

    expect(snapshot.canInlineVideo, isFalse);
    expect(snapshot.canInlineAudio, isTrue);
    expect(snapshot.canFullscreenVideo, isFalse);
  });
}
