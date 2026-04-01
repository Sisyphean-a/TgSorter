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
          rawTransport ?? TdRawTransport(logger: logger ?? TdJsonLogger());

  final TdJsonLogger _logger;
  final TdRawTransport _rawTransport;
  final StreamController<TdObject> _updatesController =
      StreamController<TdObject>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _updatesSubscription;

  @override
  Stream<TdObject> get updates => _updatesController.stream;

  @override
  Future<void> start() async {
    await _rawTransport.start();
    _updatesSubscription ??= _rawTransport.updates.listen(_forwardUpdate);
  }

  @override
  Future<void> stop() async {
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
    try {
      final event = _decodePayload(
        payload: payload,
        stage: 'typed_update',
        context: 'type=${payload['@type'] ?? 'unknown'}',
      );
      _updatesController.add(event);
    } catch (error, stackTrace) {
      if (_updatesController.hasListener) {
        _updatesController.addError(error, stackTrace);
        return;
      }
      _logger.logParseError(
        stage: 'typed_update',
        payload: jsonEncode(payload),
        reason: error.toString(),
        context: 'type=${payload['@type'] ?? 'unknown'}',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
