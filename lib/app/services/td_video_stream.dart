import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:tdlib/td_api.dart' as td;
import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

/// 将本地播放器与抽帧器的 HTTP Range 读取转换为 TDLib 的分段下载。
class TdVideoStream {
  TdVideoStream(this._adapter);

  final TdlibAdapter _adapter;
  static const _priority = 20;

  Future<TdVideoStreamSession> open(int fileId, {int? maxDownloadBytes}) async {
    final file = await _getFile(fileId);
    if (file.completed && file.path.isNotEmpty) {
      return TdVideoStreamSession._(io.File(file.path).uri);
    }
    if (file.size <= 0) {
      throw StateError('TDLib 未返回视频文件大小');
    }
    final random = math.Random.secure();
    final token = base64UrlEncode(
      List.generate(24, (_) => random.nextInt(256)),
    );
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    final uri = Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      path: '/$token',
    );
    final session = TdVideoStreamSession._(
      uri,
      server,
      maxDownloadBytes == null
          ? null
          : math.min(maxDownloadBytes, file.size - 1),
    );
    server.listen(
      (request) => unawaited(session._serve(this, fileId, file.size, request)),
    );
    return session;
  }

  Future<_LocalVideoFile> _getFile(int fileId) =>
      _requestFile(td.GetFile(fileId: fileId), 'getFile');

  Future<_LocalVideoFile> _download(int fileId, int start, int length) =>
      _requestFile(
        td.DownloadFile(
          fileId: fileId,
          priority: _priority,
          offset: start,
          limit: length,
          synchronous: false,
        ),
        'downloadFile',
      );

  Future<_LocalVideoFile> _requestFile(
    td.TdFunction function,
    String request,
  ) async {
    final response = await _adapter.sendWire(
      function,
      request: request,
      phase: TdlibPhase.business,
    );
    if (response.type != 'file') {
      throw StateError('TDLib $request 未返回文件');
    }
    return _LocalVideoFile.fromJson(response.payload);
  }
}

class TdVideoStreamSession {
  TdVideoStreamSession._(
    this.uri, [
    this._server,
    this._remainingDownloadBytes,
  ]);

  final Uri uri;
  final io.HttpServer? _server;
  static const _downloadWindow = 4 * 1024 * 1024;
  static const _thumbnailWindow = 512 * 1024;
  static const _thumbnailCacheLimit = 8 * 1024 * 1024;
  int? _remainingDownloadBytes;
  final _previewCache = SplayTreeMap<int, List<int>>();
  var _previewCacheBytes = 0;
  bool _budgetExceeded = false;
  bool get budgetExceeded => _budgetExceeded;
  static const _readChunk = 256 * 1024;
  static const _pollInterval = Duration(milliseconds: 150);
  static const _stallTimeout = Duration(seconds: 12);
  int _request = 0;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _server?.close(force: true);
  }

  Future<void> _serve(
    TdVideoStream source,
    int fileId,
    int size,
    io.HttpRequest request,
  ) async {
    final response = request.response;
    response.persistentConnection = false;
    response.bufferOutput = false;
    // 只允许持有随机地址的播放器访问当前视频，不接受外部 Host 或文件 ID。
    if (request.headers.value(io.HttpHeaders.hostHeader) != uri.authority ||
        request.uri.path != uri.path ||
        request.uri.hasQuery) {
      response.statusCode = io.HttpStatus.notFound;
      await response.close();
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = io.HttpStatus.methodNotAllowed;
      response.headers.set(io.HttpHeaders.allowHeader, 'GET, HEAD');
      await response.close();
      return;
    }

    final range = request.headers[io.HttpHeaders.rangeHeader]?.join(',');
    final bounds = _VideoByteRange.parse(range, size);
    response.headers.set(io.HttpHeaders.acceptRangesHeader, 'bytes');
    if (bounds == null) {
      response.statusCode = io.HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(io.HttpHeaders.contentRangeHeader, 'bytes */$size');
      await response.close();
      return;
    }
    if (range != null) {
      response.statusCode = io.HttpStatus.partialContent;
      response.headers.set(
        io.HttpHeaders.contentRangeHeader,
        'bytes ${bounds.start}-${bounds.end - 1}/$size',
      );
    }
    response.headers.contentType = io.ContentType.binary;
    response.contentLength = bounds.end - bounds.start;
    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    // Media3 拖动时会开启新的读取；旧请求不能再次改变 TDLib 的下载偏移。
    final generation = ++_request;
    var disconnected = false;
    unawaited(
      response.done.then<void>(
        (_) => disconnected = true,
        onError: (Object _) => disconnected = true,
      ),
    );
    bool active() => !_closed && !disconnected && generation == _request;
    try {
      await _sendBytes(source, fileId, bounds, response, active);
      if (active() && !_budgetExceeded) {
        await response.close();
      } else if (!_closed && !disconnected) {
        await _abort(response);
      }
    } catch (error, stackTrace) {
      if (active()) {
        developer.log(
          '视频分段读取失败',
          name: 'TdVideoStream',
          error: error,
          stackTrace: stackTrace,
        );
      }
      if (!_closed && !disconnected) await _abort(response);
    }
  }

  Future<void> _sendBytes(
    TdVideoStream source,
    int fileId,
    _VideoByteRange bounds,
    io.HttpResponse response,
    bool Function() active,
  ) async {
    var offset = bounds.start;
    var downloadEnd = offset;
    final stall = Stopwatch()..start();
    var file = await source._getFile(fileId);
    while (active() && offset < bounds.end) {
      final cachedStart = _previewCache.lastKeyBefore(offset + 1);
      if (cachedStart != null) {
        final cached = _previewCache[cachedStart]!;
        final start = offset - cachedStart;
        if (start < cached.length) {
          final count = math.min(cached.length - start, bounds.end - offset);
          response.add(cached.sublist(start, start + count));
          await response.flush();
          offset += count;
          stall.reset();
          continue;
        }
      }
      final available = file.availableAt(offset);
      if (available > 0) {
        final count = math.min(
          _readChunk,
          math.min(available, bounds.end - offset),
        );
        final List<int> bytes;
        try {
          bytes = await _read(file.path, offset, count);
        } on io.FileSystemException {
          if (!active()) return;
          // TDLib 下载完成时可能把临时文件移到最终路径。
          final updated = await source._getFile(fileId);
          if (updated.path == file.path || updated.availableAt(offset) <= 0) {
            rethrow;
          }
          file = updated;
          continue;
        }
        if (!active()) return;
        if (_remainingDownloadBytes != null &&
            _previewCacheBytes + bytes.length <= _thumbnailCacheLimit) {
          // 多次定位会重读容器索引；只重用本会话已经验证可读的字节。
          _previewCacheBytes +=
              bytes.length - (_previewCache[offset]?.length ?? 0);
          _previewCache[offset] = bytes;
        }
        response.add(bytes);
        await response.flush();
        offset += bytes.length;
        stall.reset();
        continue;
      }
      if (offset >= downloadEnd) {
        final remaining = _remainingDownloadBytes;
        final window = remaining == null
            ? _downloadWindow
            : math.min(_thumbnailWindow, remaining);
        final count = math.min(window, bounds.end - offset);
        if (count <= 0) {
          _budgetExceeded = true;
          return;
        }
        // 发出请求前扣除完整窗口，包括随后被取消或发生重叠的读取。
        if (remaining != null) _remainingDownloadBytes = remaining - count;
        downloadEnd = offset + count;
        file = await source._download(fileId, offset, count);
        continue;
      }
      if (stall.elapsed >= _stallTimeout) {
        throw TimeoutException('等待视频字节超时（偏移 $offset）');
      }
      await Future<void>.delayed(_pollInterval);
      if (!active()) return;
      file = await source._getFile(fileId);
    }
  }

  Future<List<int>> _read(String path, int offset, int count) async {
    final file = await io.File(path).open();
    try {
      await file.setPosition(offset);
      final bytes = await file.read(count);
      if (bytes.length != count) {
        throw io.FileSystemException('TDLib 缓存段不完整', path);
      }
      return bytes;
    } finally {
      await file.close();
    }
  }

  Future<void> _abort(io.HttpResponse response) async {
    try {
      final socket = await response.detachSocket(writeHeaders: false);
      socket.destroy();
    } on io.IOException {
      // 播放器可能已主动关掉旧连接。
    } on StateError {
      // 响应可能已因客户端断开而关闭。
    }
  }
}

class _LocalVideoFile {
  _LocalVideoFile.fromJson(Map<String, dynamic> json)
    : size = TdResponseReader.readInt(json, 'size'),
      local = TdResponseReader.readMap(json, 'local');

  final int size;
  final Map<String, dynamic> local;
  String get path => local['path'] as String? ?? '';
  bool get completed => local['is_downloading_completed'] == true;

  int availableAt(int offset) {
    if (path.isEmpty) return 0;
    if (completed) return size - offset;
    final start = TdResponseReader.readInt(local, 'download_offset');
    final prefix = TdResponseReader.readInt(local, 'downloaded_prefix_size');
    return offset >= start ? start + prefix - offset : 0;
  }
}

class _VideoByteRange {
  const _VideoByteRange(this.start, this.end);
  final int start;
  final int end;

  static final _range = RegExp(r'^bytes=(\d*)-(\d*)$');

  static _VideoByteRange? parse(String? header, int size) {
    if (header == null) return _VideoByteRange(0, size);
    final match = _range.firstMatch(header);
    if (match == null) return null;
    final left = match[1]!;
    final right = match[2]!;
    final start = int.tryParse(left);
    final last = int.tryParse(right);
    if (left.isEmpty) {
      if (last == null || last <= 0) return null;
      return _VideoByteRange(math.max(0, size - last), size);
    }
    if (start == null ||
        start >= size ||
        (right.isNotEmpty && (last == null || last < start))) {
      return null;
    }
    return _VideoByteRange(
      start,
      last == null || last >= size - 1 ? size : last + 1,
    );
  }
}
