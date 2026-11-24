import 'dart:typed_data';

class VideoThumbnail {
  const VideoThumbnail(this.position, this.bytes);

  final Duration position;
  final Uint8List bytes;
}

enum VideoThumbnailPhase { reading, decoding }

class VideoThumbnailBudget {
  int _remaining = VideoThumbnailPreview.downloadBudgetMiB * 1024 * 1024;

  int get remainingBytes => _remaining;
  void charge(int bytes) => _remaining -= bytes;
}

abstract interface class VideoThumbnailPreview {
  static const downloadBudgetMiB = 12;

  Stream<VideoThumbnail> generate(
    int fileId,
    int durationSeconds, {
    Iterable<Duration>? positions,
    VideoThumbnailBudget? budget,
    void Function(VideoThumbnailPhase phase)? onPhase,
  });
}

List<Duration> videoThumbnailPositions(int durationSeconds) {
  if (durationSeconds <= 0) throw ArgumentError.value(durationSeconds);
  final count = durationSeconds < 600 ? 2 : (durationSeconds > 3600 ? 6 : 4);
  return List.generate(
    count,
    (index) => Duration(
      milliseconds: durationSeconds * 1000 * (index + 1) ~/ (count + 1),
    ),
    growable: false,
  );
}
