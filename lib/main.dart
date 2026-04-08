import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:tgsorter/app/bootstrap_app.dart';
import 'package:tgsorter/app/core/di/app_bindings.dart';
import 'package:tgsorter/app/services/audio_playback_initializer.dart';
import 'package:tgsorter/app/services/video_playback_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeAudioPlayback();
  await initializeVideoPlayback();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _recordStartupError('FlutterError: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _recordStartupError('PlatformError: $error\n$stack');
    return false;
  };
  runApp(const BootstrapApp(init: registerAppBindings));
}

void _recordStartupError(String message) {
  try {
    final file = File('startup_error.log');
    final now = DateTime.now().toIso8601String();
    file.writeAsStringSync('[$now] $message\n', mode: FileMode.append);
  } catch (_) {}
}
