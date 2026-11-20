import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart' as td;
import 'package:tgsorter/app/services/td_video_stream.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  late Directory directory;
  late File cache;
  late _VideoFileAdapter adapter;
  late HttpClient client;
  const fileSize = 10 * 1024 * 1024;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('td-video-stream-test');
    cache = File('${directory.path}/video');
    final handle = await cache.open(mode: FileMode.write);
    await handle.truncate(fileSize);
    await handle.setPosition(6 * 1024 * 1024);
    await handle.writeFrom([4, 5, 6, 7]);
    await handle.setPosition(0);
    await handle.writeFrom([1, 2, 3]);
    await handle.close();
    adapter = _VideoFileAdapter(cache.path, fileSize);
    client = HttpClient()..findProxy = (_) => 'DIRECT';
  });

  tearDown(() async {
    client.close(force: true);
    await directory.delete(recursive: true);
  });

  test('首段就绪即返回，不等到 TDLib 下载整个视频；新读取跳到未缓存偏移', () async {
    adapter.prefix = 3;
    final session = await TdVideoStream(adapter).open(42);
    addTearDown(session.close);

    final start = await (await client.getUrl(session.uri)).close();
    expect(start.statusCode, HttpStatus.ok);
    expect(start.contentLength, fileSize);
    final firstBytes = Completer<List<int>>();
    final startSubscription = start.listen((data) {
      if (!firstBytes.isCompleted) firstBytes.complete(data);
    }, onError: (Object _) {});
    expect(await firstBytes.future, [1, 2, 3]);
    // 模拟播放器直接从另一个位置重新发起读取，不等待旧响应关闭。
    unawaited(startSubscription.cancel());

    const seekOffset = 6 * 1024 * 1024;
    final seekRequest = await client.getUrl(session.uri);
    seekRequest.headers.set(
      HttpHeaders.rangeHeader,
      'bytes=$seekOffset-${seekOffset + 3}',
    );
    final sought = await seekRequest.close();
    expect(sought.statusCode, HttpStatus.partialContent);
    expect(
      sought.headers.value(HttpHeaders.contentRangeHeader),
      'bytes $seekOffset-${seekOffset + 3}/$fileSize',
    );
    expect(await sought.expand((bytes) => bytes).toList(), [4, 5, 6, 7]);
    expect(adapter.downloads.last, (seekOffset, 4));
    expect(adapter.completed, isFalse);
  });

  test('不会把稀疏缓存中的未就绪字节返回给播放器', () async {
    final allowDownload = Completer<void>();
    final started = Completer<void>();
    adapter.onDownload = (offset, length) {
      adapter.offset = offset;
      adapter.prefix = 0;
      started.complete();
      unawaited(allowDownload.future.then((_) => adapter.prefix = length));
    };
    final session = await TdVideoStream(adapter).open(42);
    addTearDown(session.close);
    final request = await client.getUrl(session.uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-2');
    var received = false;
    final body = request.close().then((response) async {
      received = true;
      return response.expand((bytes) => bytes).toList();
    });
    await started.future;
    expect(received, isFalse);
    allowDownload.complete();
    expect(await body, [1, 2, 3]);
  });

  test('拒绝未知地址、错误 Host、非法范围，HEAD 不触发下载', () async {
    final session = await TdVideoStream(adapter).open(42);
    addTearDown(session.close);

    final unknown = await (await client.getUrl(
      session.uri.replace(path: '/42'),
    )).close();
    expect(unknown.statusCode, HttpStatus.notFound);
    await unknown.drain<void>();

    final wrongHost = await client.getUrl(session.uri);
    wrongHost.headers.set(HttpHeaders.hostHeader, 'external.test');
    final rejected = await wrongHost.close();
    expect(rejected.statusCode, HttpStatus.notFound);
    await rejected.drain<void>();

    final invalid = await client.getUrl(session.uri);
    invalid.headers.set(HttpHeaders.rangeHeader, 'bytes=$fileSize-');
    final outOfBounds = await invalid.close();
    expect(outOfBounds.statusCode, HttpStatus.requestedRangeNotSatisfiable);
    expect(
      outOfBounds.headers.value(HttpHeaders.contentRangeHeader),
      'bytes */$fileSize',
    );
    await outOfBounds.drain<void>();

    final head = await client.headUrl(session.uri);
    head.headers.set(HttpHeaders.rangeHeader, 'bytes=-4');
    final info = await head.close();
    expect(info.statusCode, HttpStatus.partialContent);
    expect(info.contentLength, 4);
    expect(await info.expand((bytes) => bytes).toList(), isEmpty);
    expect(adapter.downloads, isEmpty);
  });

  test('已完整缓存的视频直接返回本地文件，不启动下载', () async {
    adapter.completed = true;
    final session = await TdVideoStream(adapter).open(42);
    addTearDown(session.close);
    expect(session.uri, cache.uri);
    expect(adapter.downloads, isEmpty);
  });
}

class _VideoFileAdapter implements TdlibAdapter {
  _VideoFileAdapter(this.path, this.size);

  final String path;
  final int size;
  final List<(int, int)> downloads = [];
  int offset = 0;
  int prefix = 0;
  bool completed = false;
  void Function(int, int)? onDownload;

  @override
  Future<TdWireEnvelope> sendWire(
    td.TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (function is td.DownloadFile) {
      final start = function.offset;
      final length = function.limit;
      expect(function.synchronous, isFalse);
      downloads.add((start, length));
      if (onDownload case final download?) {
        download(start, length);
      } else if (length <= 4) {
        offset = start;
        prefix = length;
      }
    } else {
      expect(function, isA<td.GetFile>());
    }
    return TdWireEnvelope.fromJson({
      '@type': 'file',
      'id': 42,
      'size': size,
      'local': {
        'path': path,
        'download_offset': offset,
        'downloaded_prefix_size': prefix,
        'is_downloading_completed': completed,
      },
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
