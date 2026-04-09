import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/audio_playback_initializer.dart';

void main() {
  group('initializeAudioPlayback', () {
    test('enables windows audio backend only on windows', () async {
      AudioBackendInitCall? captured;

      await initializeAudioPlayback(
        targetPlatform: const AudioBackendPlatform(isWindows: true),
        initializer: ({required bool windows, required bool linux}) async {
          captured = AudioBackendInitCall(windows: windows, linux: linux);
        },
      );

      expect(captured, isNotNull);
      expect(captured?.windows, isTrue);
      expect(captured?.linux, isFalse);
    });
  });
}
