import 'dart:io';
import 'dart:async';

import 'package:video_player_media_kit/video_player_media_kit.dart';

typedef VideoBackendInitializer =
    FutureOr<void> Function({
      required bool android,
      required bool iOS,
      required bool macOS,
      required bool windows,
      required bool linux,
      required bool web,
    });

class VideoBackendPlatform {
  const VideoBackendPlatform({
    required this.isAndroid,
    required this.isWindows,
  });

  final bool isAndroid;
  final bool isWindows;
}

class VideoBackendInitCall {
  const VideoBackendInitCall({
    required this.android,
    required this.iOS,
    required this.macOS,
    required this.windows,
    required this.linux,
  });

  final bool android;
  final bool iOS;
  final bool macOS;
  final bool windows;
  final bool linux;
}

Future<void> initializeVideoPlayback({
  VideoBackendPlatform? targetPlatform,
  VideoBackendInitializer initializer = VideoPlayerMediaKit.ensureInitialized,
}) async {
  final platform =
      targetPlatform ??
      VideoBackendPlatform(
        isAndroid: Platform.isAndroid,
        isWindows: Platform.isWindows,
      );
  await initializer(
    android: platform.isAndroid,
    iOS: false,
    macOS: false,
    windows: platform.isWindows,
    linux: false,
    web: false,
  );
}
