import 'dart:typed_data';

class VideoThumbnail {
  const VideoThumbnail(this.position, this.bytes);

  final Duration position;
  final Uint8List bytes;
}

abstract interface class VideoThumbnailPreview {
  static const downloadBudgetMiB = 12;

  Stream<VideoThumbnail> generate(int fileId, int durationSeconds);
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
