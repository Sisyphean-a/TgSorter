import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart' show GetFile, TdFunction;
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/services/td_video_stream.dart';
import 'package:tgsorter/app/services/td_video_thumbnail_preview.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const channel = MethodChannel('tgsorter/video_thumbnail');
  late TdVideoThumbnailPreview preview;
  late List<MethodCall> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    final file = File('${Directory.systemTemp.path}/video.mp4');
    preview = TdVideoThumbnailPreview(TdVideoStream(_CachedVideo(file.path)));
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('安卓复用一个抽帧会话，有序返回六帧后关闭', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'extract' ? Uint8List.fromList([1, 2]) : null;
    });

    final frames = await preview.generate(42, 4200).toList();

    final extracts = calls.where((call) => call.method == 'extract').toList();
    final id = extracts.first.arguments['sessionId'];
    expect(id, isA<int>());
    expect(
      extracts.map((call) => call.arguments['sessionId']),
      everyElement(id),
    );
    expect(extracts.map((call) => call.arguments['local']), everyElement(true));
    expect(frames.map((frame) => frame.position.inSeconds), [
      600,
      1200,
      1800,
      2400,
      3000,
      3600,
    ]);
    expect(calls.last.method, 'close');
    expect(calls.last.arguments, id);
  });

  testWidgets('不再固定 12 秒截断，解码无进展时报告阶段并关闭会话', (tester) async {
    final pending = Completer<Uint8List>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'extract' ? pending.future : null;
    });
    final errors = <Object>[];
    final phases = <VideoThumbnailPhase>[];
    final subscription = preview
        .generate(42, 300, onPhase: phases.add)
        .listen((_) {}, onError: errors.add);
    await tester.pump();
    await tester.pump(const Duration(seconds: 13));
    expect(errors, isEmpty);
    expect(phases, [VideoThumbnailPhase.reading, VideoThumbnailPhase.decoding]);
    await tester.pump(const Duration(seconds: 13));
    expect(
      errors.single,
      isA<TimeoutException>().having(
        (error) => error.message,
        '阶段',
        contains('解码画面'),
      ),
    );
    expect(calls.last.method, 'close');
    pending.complete(Uint8List.fromList([1]));
    await subscription.cancel();
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  test('取消时关闭原生会话，迟到的帧不再交付', () async {
    final secondStarted = Completer<void>();
    final pending = Completer<Uint8List>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'close') return null;
      if (calls.length == 1) return Uint8List.fromList([1]);
      secondStarted.complete();
      return pending.future;
    });
    final delivered = <Duration>[];
    final subscription = preview
        .generate(42, 900)
        .listen((frame) => delivered.add(frame.position));
    await secondStarted.future;
    await subscription.cancel();
    pending.complete(Uint8List.fromList([2]));
    await Future<void>.delayed(Duration.zero);
    expect(delivered, [const Duration(seconds: 180)]);
    expect(calls.map((call) => call.method), ['extract', 'extract', 'close']);
    expect(calls.last.arguments, calls.first.arguments['sessionId']);
  });
}

class _CachedVideo extends Fake implements TdlibAdapter {
  _CachedVideo(this.path);

  final String path;

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    expect(function, isA<GetFile>());
    return TdWireEnvelope.fromJson({
      '@type': 'file',
      'size': 100,
      'local': {'is_downloading_completed': true, 'path': path},
    });
  }
}
