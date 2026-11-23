import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/services/td_video_stream.dart';

class TdVideoThumbnailPreview implements VideoThumbnailPreview {
  const TdVideoThumbnailPreview(this._source);

  final TdVideoStream _source;
  static const _channel = MethodChannel('tgsorter/video_thumbnail');
  static const _frameTimeout = Duration(seconds: 12);

  @override
  Stream<VideoThumbnail> generate(int fileId, int durationSeconds) {
    final positions = videoThumbnailPositions(durationSeconds);
    TdVideoStreamSession? session;
    var cancelled = false;
    final controller = StreamController<VideoThumbnail>(
      onCancel: () async {
        cancelled = true;
        await session?.close();
      },
    );
    controller.onListen = () async {
      try {
        final source = session = await _source.open(
          fileId,
          maxDownloadBytes:
              VideoThumbnailPreview.downloadBudgetMiB * 1024 * 1024,
        );
        for (final position in positions) {
          if (cancelled) return;
          if (source.budgetExceeded) throw StateError('已达本次分段读取上限');
          final bytes = await _extract(
            source.uri,
            position,
          ).timeout(_frameTimeout);
          if (cancelled) return;
          if (bytes == null || bytes.isEmpty) throw StateError('无法读取该时间点的画面');
          controller.add(VideoThumbnail(position, bytes));
        }
      } catch (error, stack) {
        if (!cancelled) {
          controller.addError(
            session?.budgetExceeded == true
                ? StateError('已达本次分段读取上限，未下载完整视频')
                : error,
            stack,
          );
        }
      } finally {
        await session?.close();
        unawaited(controller.close());
      }
    };
    return controller.stream;
  }

  Future<Uint8List?> _extract(Uri source, Duration position) {
    if (Platform.isAndroid) {
      return _channel.invokeMethod<Uint8List>('extract', {
        'source': source.isScheme('file')
            ? source.toFilePath()
            : source.toString(),
        'local': source.isScheme('file'),
        'positionUs': position.inMicroseconds,
      });
    }
    if (Platform.isWindows) return _extractWithMpv(source, position);
    throw UnsupportedError('当前平台不支持视频抽帧');
  }

  Future<Uint8List?> _extractWithMpv(Uri source, Duration position) async {
    MediaKit.ensureInitialized();
    final player = Player(
      configuration: const PlayerConfiguration(
        vo: 'null',
        bufferSize: 512 * 1024,
      ),
    );
    try {
      final native = player.platform as NativePlayer;
      await native.setProperty('vid', 'auto');
      await native.setProperty('aid', 'no');
      await native.setProperty('cache', 'no');
      await native.setProperty('hr-seek', 'yes');
      await player.open(Media(source.toString(), start: position), play: false);
      if (player.state.position < position) {
        await player.stream.position
            .firstWhere((value) => value >= position)
            .timeout(_frameTimeout);
      }
      // time-pos 可能先于画面到位；等待首帧，不开始连续播放。
      final wait = Stopwatch()..start();
      while (wait.elapsed < _frameTimeout) {
        final bytes = await player.screenshot();
        if (bytes != null) return bytes;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return null;
    } finally {
      await player.dispose();
    }
  }
}
