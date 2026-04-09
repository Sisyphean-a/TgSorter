import 'dart:async';
import 'dart:io';

import 'package:just_audio_media_kit/just_audio_media_kit.dart';

typedef AudioBackendInitializer =
    FutureOr<void> Function({required bool windows, required bool linux});

class AudioBackendPlatform {
  const AudioBackendPlatform({this.isWindows = false, this.isLinux = false});

  final bool isWindows;
  final bool isLinux;
}

class AudioBackendInitCall {
  const AudioBackendInitCall({required this.windows, required this.linux});

  final bool windows;
  final bool linux;
}

Future<void> initializeAudioPlayback({
  AudioBackendPlatform? targetPlatform,
  AudioBackendInitializer initializer = _ensureAudioBackend,
}) async {
  final platform =
      targetPlatform ??
      AudioBackendPlatform(
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
      );
  await initializer(windows: platform.isWindows, linux: platform.isLinux);
}

void _ensureAudioBackend({required bool windows, required bool linux}) {
  JustAudioMediaKit.title = 'TgSorter';
  JustAudioMediaKit.ensureInitialized(windows: windows, linux: linux);
}
