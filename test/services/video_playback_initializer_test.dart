import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/video_playback_initializer.dart';

void main() {
  group('initializeVideoPlayback', () {
    test('enables android and windows backends only', () async {
      VideoBackendInitCall? captured;

      await initializeVideoPlayback(
        targetPlatform: const VideoBackendPlatform(
          isAndroid: true,
          isWindows: true,
        ),
        initializer:
            ({
              required bool android,
              required bool iOS,
              required bool macOS,
              required bool windows,
              required bool linux,
              required bool web,
            }) async {
              captured = VideoBackendInitCall(
                android: android,
                iOS: iOS,
                macOS: macOS,
                windows: windows,
                linux: linux,
              );
            },
      );

      expect(captured, isNotNull);
      expect(captured?.android, isTrue);
      expect(captured?.windows, isTrue);
      expect(captured?.iOS, isFalse);
      expect(captured?.macOS, isFalse);
      expect(captured?.linux, isFalse);
    });
  });
}
