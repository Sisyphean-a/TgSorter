import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/services/td_video_stream.dart';

class TdVideoThumbnailPreview implements VideoThumbnailPreview {
  const TdVideoThumbnailPreview(this._source);

  final TdVideoStream _source;
  static const _channel = MethodChannel('tgsorter/video_thumbnail');
  static int _nextAndroidSession = 0;

  @override
  Stream<VideoThumbnail> generate(
    int fileId,
    int durationSeconds, {
    Iterable<Duration>? positions,
    VideoThumbnailBudget? budget,
    void Function(VideoThumbnailPhase phase)? onPhase,
  }) {
    final targets = (positions ?? videoThumbnailPositions(durationSeconds))
        .toList();
    final allowance = budget ?? VideoThumbnailBudget();
    TdVideoStreamSession? session;
    _FrameWatchdog? watchdog;
    int? androidSession;
    var cancelled = false;

    Future<void> closeSession() async {
      final id = androidSession;
      androidSession = null;
      watchdog?.stop();
      if (id != null) unawaited(_closeAndroidSession(id));
      await session?.close();
    }

    final controller = StreamController<VideoThumbnail>(
      onCancel: () async {
        cancelled = true;
        await closeSession();
      },
    );
    controller.onListen = () async {
      try {
        onPhase?.call(VideoThumbnailPhase.reading);
        final source = session = await _source.open(
          fileId,
          maxDownloadBytes: allowance.remainingBytes,
          onDownloadRequested: allowance.charge,
          onReadActivity: (activity) {
            switch (activity) {
              case TdVideoReadActivity.waiting:
                watchdog?.change(VideoThumbnailPhase.reading);
              case TdVideoReadActivity.bytes:
                watchdog?.change(
                  VideoThumbnailPhase.decoding,
                  progressed: true,
                );
              case TdVideoReadActivity.delivered:
                watchdog?.change(VideoThumbnailPhase.decoding);
              case TdVideoReadActivity.budgetExceeded:
                watchdog?.fail(StateError('已达本次分段读取上限'));
            }
          },
        );
        if (cancelled) return;
        if (defaultTargetPlatform == TargetPlatform.android) {
          androidSession = ++_nextAndroidSession;
        }
        for (final position in targets) {
          if (cancelled) return;
          if (source.budgetExceeded) throw StateError('已达本次分段读取上限');
          final frame = watchdog = _FrameWatchdog(onPhase);
          frame.change(
            source.uri.isScheme('file')
                ? VideoThumbnailPhase.decoding
                : VideoThumbnailPhase.reading,
          );
          final bytes = await Future.any<Uint8List?>([
            frame.interrupted,
            _extract(source.uri, position, androidSession, frame),
          ]);
          frame.stop();
          watchdog = null;
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
        try {
          await closeSession();
        } finally {
          unawaited(controller.close());
        }
      }
    };
    return controller.stream;
  }

  Future<void> _closeAndroidSession(int id) async {
    try {
      await _channel.invokeMethod<void>('close', id);
    } catch (error, stackTrace) {
      developer.log(
        '释放 Android 抽帧会话失败',
        name: 'TdVideoThumbnailPreview',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<Uint8List?> _extract(
    Uri source,
    Duration position,
    int? androidSession,
    _FrameWatchdog watchdog,
  ) {
    if (androidSession != null) {
      return _channel.invokeMethod<Uint8List>('extract', {
        'sessionId': androidSession,
        'source': source.isScheme('file')
            ? source.toFilePath()
            : source.toString(),
        'local': source.isScheme('file'),
        'positionUs': position.inMicroseconds,
      });
    }
    if (Platform.isWindows) return _extractWithMpv(source, position, watchdog);
    throw UnsupportedError('当前平台不支持视频抽帧');
  }

  Future<Uint8List?> _extractWithMpv(
    Uri source,
    Duration position,
    _FrameWatchdog watchdog,
  ) async {
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
      await native.setProperty(
        'network-timeout',
        _FrameWatchdog.readIdle.inSeconds.toString(),
      );
      if (watchdog.stopped) return null;
      await player.open(Media(source.toString(), start: position), play: false);
      if (watchdog.stopped) return null;
      if (player.state.position < position) {
        await Future.any<Object?>([
          player.stream.position.firstWhere((value) => value >= position),
          watchdog.interrupted,
        ]);
      }
      // time-pos 可能先于画面到位；等待首帧，不开始连续播放。
      while (!watchdog.stopped) {
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

class _FrameWatchdog {
  _FrameWatchdog(this.onPhase);

  static const readIdle = Duration(seconds: 30);
  static const _decodeIdle = Duration(seconds: 25);
  final void Function(VideoThumbnailPhase phase)? onPhase;
  final _interrupted = Completer<Uint8List?>();
  VideoThumbnailPhase? _phase;
  Timer? _timer;

  Future<Uint8List?> get interrupted => _interrupted.future;
  bool get stopped => _interrupted.isCompleted;

  void change(VideoThumbnailPhase phase, {bool progressed = false}) {
    if (stopped || (_phase == phase && !progressed)) return;
    _timer?.cancel();
    final reading = phase == VideoThumbnailPhase.reading;
    _timer = Timer(reading ? readIdle : _decodeIdle, () {
      fail(TimeoutException(reading ? '读取视频分段长时间没有进展' : '解码画面长时间没有进展'));
    });
    if (_phase == phase) return;
    _phase = phase;
    onPhase?.call(phase);
  }

  void fail(Object error) {
    _timer?.cancel();
    if (!stopped) _interrupted.completeError(error);
  }

  void stop() {
    _timer?.cancel();
    if (!stopped) _interrupted.complete(null);
  }
}
