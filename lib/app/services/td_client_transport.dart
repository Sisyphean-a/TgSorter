import 'dart:async';
import 'dart:convert';

import 'package:tdlib/td_api.dart';

import 'td_json_logger.dart';
import 'td_raw_transport.dart';

abstract class TdTransport {
  Stream<TdObject> get updates;

  Future<void> start();
  Future<void> stop();
  Future<TdObject> send(TdFunction function);
  Future<TdObject> sendWithTimeout(TdFunction function, Duration timeout);
  void sendWithoutResponse(TdFunction function);
}

class TdClientTransport implements TdTransport {
  TdClientTransport({TdRawTransport? rawTransport, TdJsonLogger? logger})
    : _logger = logger ?? TdJsonLogger(),
      _rawTransport =
          rawTransport ?? TdRawTransport(logger: logger ?? TdJsonLogger()) {
    _updatesController = StreamController<TdObject>.broadcast(
      onListen: _ensureUpdateBridge,
      onCancel: _handleUpdateStreamCancel,
    );
  }

  final TdJsonLogger _logger;
  final TdRawTransport _rawTransport;
  late final StreamController<TdObject> _updatesController;
  StreamSubscription<Map<String, dynamic>>? _updatesSubscription;
  bool _started = false;

  @override
  Stream<TdObject> get updates => _updatesController.stream;

  @override
  Future<void> start() async {
    await _rawTransport.start();
    _started = true;
    _ensureUpdateBridge();
  }

  @override
  Future<void> stop() async {
    _started = false;
    await _updatesSubscription?.cancel();
    _updatesSubscription = null;
    await _rawTransport.stop();
  }

  @override
  Future<TdObject> send(TdFunction function) async {
    return sendWithTimeout(function, const Duration(seconds: 20));
  }

  @override
  void sendWithoutResponse(TdFunction function) {
    _rawTransport.sendWithoutResponse(function);
  }

  @override
  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    final payload = await _rawTransport.send(function, timeout: timeout);
    return _decodePayload(
      payload: payload,
      stage: 'typed_response',
      context: 'request=${function.getConstructor()}',
    );
  }

  void _forwardUpdate(Map<String, dynamic> payload) {
    final event = _tryDecodeUpdate(payload);
    if (event != null) {
      _updatesController.add(event);
    }
  }

  void _ensureUpdateBridge() {
    if (!_started ||
        !_updatesController.hasListener ||
        _updatesSubscription != null) {
      return;
    }
    _updatesSubscription = _rawTransport.updates.listen(_forwardUpdate);
  }

  void _handleUpdateStreamCancel() {
    if (_updatesController.hasListener) {
      return;
    }
    unawaited(_cancelUpdateBridge());
  }

  Future<void> _cancelUpdateBridge() async {
    await _updatesSubscription?.cancel();
    _updatesSubscription = null;
  }

  TdObject? _tryDecodeUpdate(Map<String, dynamic> payload) {
    final encoded = jsonEncode(payload);
    final event = convertToObject(encoded);
    if (event == null) {
      return null;
    }
    return event;
  }

  TdObject _decodePayload({
    required Map<String, dynamic> payload,
    required String stage,
    required String context,
  }) {
    try {
      final event = convertToObject(jsonEncode(payload));
      if (event == null) {
        throw StateError('TDLib payload cannot be converted to TdObject');
      }
      return event;
    } catch (error, stackTrace) {
      _logger.logParseError(
        stage: stage,
        payload: jsonEncode(payload),
        reason: error.toString(),
        context: context,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
