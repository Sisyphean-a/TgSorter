import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

typedef VideoControllerInitializer =
    Future<void> Function(VideoPlayerController controller);

const double previewMediaHeight = 240;

Duration clampVideoSeekTarget({
  required Duration target,
  required Duration duration,
}) {
  if (duration <= Duration.zero) {
    return Duration.zero;
  }
  if (target <= Duration.zero) {
    return Duration.zero;
  }
  if (target >= duration) {
    return duration;
  }
  return target;
}

String formatPreviewDuration(int totalSeconds) {
  final safe = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = safe ~/ 60;
  final seconds = safe % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

class PreviewMetaText extends StatelessWidget {
  const PreviewMetaText({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class PreviewPlaceholder extends StatelessWidget {
  const PreviewPlaceholder({
    super.key,
    required this.text,
    this.height = previewMediaHeight,
    this.textColor = Colors.white,
  });

  final String text;
  final double height;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      color: Colors.black12,
      alignment: Alignment.center,
      child: Text(text, style: TextStyle(color: textColor)),
    );
  }
}

class PreviewImage extends StatelessWidget {
  const PreviewImage({
    super.key,
    required this.imagePath,
    required this.fallbackText,
    this.height = previewMediaHeight,
  });

  final String? imagePath;
  final String fallbackText;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return PreviewPlaceholder(text: fallbackText);
    }
    return Image.file(
      io.File(imagePath!),
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const PreviewPlaceholder(text: '图片加载失败'),
    );
  }
}
