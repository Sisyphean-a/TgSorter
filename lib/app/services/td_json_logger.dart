import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

typedef TdLogSink =
    void Function({
      required String message,
      required String name,
      Object? error,
      StackTrace? stackTrace,
    });

class TdJsonLogger {
  TdJsonLogger({bool? isEnabled, TdLogSink? sink})
    : _isEnabled = isEnabled ?? kDebugMode,
      _sink = sink ?? _defaultSink;

  static const String loggerName = 'TdJsonLogger';
  static const Set<String> _suppressedUpdateTypes = <String>{'updateOption'};

  final bool _isEnabled;
  final TdLogSink _sink;

  void logSend({
    required String request,
    required Object? extra,
    required Object payload,
  }) {
    _log(
      '[TD SEND] request=$request extra=${extra ?? 'null'} '
      'payload=${_encodePayload(payload)}',
    );
  }

  void logReceive({
    required String type,
    required Object? extra,
    required Object payload,
  }) {
    _log(
      '[TD RECV] type=$type extra=${extra ?? 'null'} '
      'payload=${_encodePayload(payload)}',
    );
  }

  void logUpdate({required String type, required Object payload}) {
    if (_suppressedUpdateTypes.contains(type)) {
      return;
    }
    _log('[TD UPDATE] type=$type payload=${_encodePayload(payload)}');
  }

  void logParseError({
    required String stage,
    required String payload,
    required String reason,
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final contextPart = context == null ? '' : ' context=$context';
    _log(
      '[TD PARSE ERROR] stage=$stage$contextPart reason=$reason '
      'payload=$payload',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_isEnabled) {
      return;
    }
    _sink(
      message: message,
      name: loggerName,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _defaultSink({
    required String message,
    required String name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(message, name: name, error: error, stackTrace: stackTrace);
  }

  String _encodePayload(Object payload) {
    if (payload is String) {
      return payload;
    }
    return jsonEncode(payload);
  }
}
