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

enum TdJsonLogDetailLevel { summary, verbose }

TdJsonLogDetailLevel parseTdJsonLogDetailLevel(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'verbose':
    case 'debug':
      return TdJsonLogDetailLevel.verbose;
    default:
      return TdJsonLogDetailLevel.summary;
  }
}

class TdJsonLogger {
  TdJsonLogger({
    bool? isEnabled,
    TdLogSink? sink,
    TdJsonLogDetailLevel detailLevel = TdJsonLogDetailLevel.summary,
    DateTime Function()? now,
    Duration dedupeWindow = const Duration(seconds: 2),
  })
    : _isEnabled = isEnabled ?? kDebugMode,
      _sink = sink ?? _defaultSink,
      _detailLevel = detailLevel,
      _now = now ?? DateTime.now,
      _dedupeWindow = dedupeWindow;

  static const String loggerName = 'TdJsonLogger';
  static const Set<String> _suppressedUpdateTypes = <String>{'updateOption'};

  final bool _isEnabled;
  final TdLogSink _sink;
  final TdJsonLogDetailLevel _detailLevel;
  final DateTime Function() _now;
  final Duration _dedupeWindow;
  final Map<String, DateTime> _recentUpdateFingerprints = <String, DateTime>{};

  void logSend({
    required String request,
    required Object? extra,
    required Object payload,
  }) {
    _log(
      '[TD SEND][$_detailLabel] request=$request extra=${extra ?? 'null'} '
      '${_describePayload(payload)}',
    );
  }

  void logReceive({
    required String type,
    required Object? extra,
    required Object payload,
  }) {
    _log(
      '[TD RECV][$_detailLabel] type=$type extra=${extra ?? 'null'} '
      '${_describePayload(payload)}',
    );
  }

  void logUpdate({required String type, required Object payload}) {
    if (_suppressedUpdateTypes.contains(type)) {
      return;
    }
    if (_shouldSuppressUpdateFingerprint(_updateFingerprint(type, payload))) {
      return;
    }
    _log(
      '[TD UPDATE][$_detailLabel] type=$type ${_describePayload(payload)}',
    );
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

  String get _detailLabel {
    switch (_detailLevel) {
      case TdJsonLogDetailLevel.summary:
        return 'summary';
      case TdJsonLogDetailLevel.verbose:
        return 'debug';
    }
  }

  String _describePayload(Object payload) {
    if (_detailLevel == TdJsonLogDetailLevel.verbose) {
      return 'payload=${_encodePayload(payload)}';
    }
    return _summarizePayload(payload);
  }

  String _summarizePayload(Object payload) {
    if (payload is String) {
      return 'raw=${_truncate(payload)}';
    }
    if (payload is! Map) {
      return 'value=${_truncate(_encodePayload(payload))}';
    }
    final map = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    final summary = _knownPayloadSummary(map);
    if (summary != null) {
      return summary;
    }
    final parts = <String>[];
    for (final entry in map.entries) {
      if (entry.key == '@type' || entry.key == '@extra') {
        continue;
      }
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        parts.add('${entry.key}=$value');
      }
      if (parts.length >= 3) {
        break;
      }
    }
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    final keys = map.keys
        .where((key) => key != '@type' && key != '@extra')
        .take(4)
        .join(',');
    return keys.isEmpty ? 'payload=empty' : 'keys=$keys';
  }

  String? _knownPayloadSummary(Map<String, dynamic> payload) {
    final type = payload['@type']?.toString();
    switch (type) {
      case 'updateNewMessage':
        final message = _asMap(payload['message']);
        if (message == null) {
          return null;
        }
        final chatId = message['chat_id'];
        final messageId = message['id'];
        final contentType = _contentTypeOf(message['content']);
        return _joinSummaryParts(<String>[
          if (chatId != null) 'chat_id=$chatId',
          if (messageId != null) 'message_id=$messageId',
          if (contentType != null) 'content=$contentType',
        ]);
      case 'updateChatLastMessage':
        final lastMessage = _asMap(payload['last_message']);
        final chatId = payload['chat_id'];
        final messageId = lastMessage?['id'];
        final contentType = _contentTypeOf(lastMessage?['content']);
        return _joinSummaryParts(<String>[
          if (chatId != null) 'chat_id=$chatId',
          if (messageId != null) 'message_id=$messageId',
          if (contentType != null) 'content=$contentType',
        ]);
      case 'getChatHistory':
        return _joinSummaryParts(<String>[
          if (payload['chat_id'] != null) 'chat_id=${payload['chat_id']}',
          if (payload['from_message_id'] != null)
            'from_message_id=${payload['from_message_id']}',
          if (payload['limit'] != null) 'limit=${payload['limit']}',
        ]);
      case 'updateFile':
        final file = _asMap(payload['file']);
        if (file == null) {
          return null;
        }
        final local = _asMap(file['local']);
        return _joinSummaryParts(<String>[
          if (file['id'] != null) 'file_id=${file['id']}',
          if (local?['is_downloading_completed'] != null)
            'downloaded=${local?['is_downloading_completed']}',
          if (local?['downloaded_size'] != null)
            'downloaded_size=${local?['downloaded_size']}',
        ]);
    }
    return null;
  }

  String? _updateFingerprint(String type, Object payload) {
    if (payload is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    switch (type) {
      case 'updateNewMessage':
        final message = _asMap(map['message']);
        final chatId = message?['chat_id'];
        final messageId = message?['id'];
        if (chatId == null || messageId == null) {
          return null;
        }
        return 'message:$chatId:$messageId';
      case 'updateChatLastMessage':
        final lastMessage = _asMap(map['last_message']);
        final chatId = map['chat_id'];
        final messageId = lastMessage?['id'];
        if (chatId == null || messageId == null) {
          return null;
        }
        return 'message:$chatId:$messageId';
    }
    return null;
  }

  bool _shouldSuppressUpdateFingerprint(String? fingerprint) {
    if (fingerprint == null) {
      return false;
    }
    final now = _now();
    _recentUpdateFingerprints.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _dedupeWindow,
    );
    final previous = _recentUpdateFingerprints[fingerprint];
    if (previous != null && now.difference(previous) <= _dedupeWindow) {
      return true;
    }
    _recentUpdateFingerprints[fingerprint] = now;
    return false;
  }

  Map<String, dynamic>? _asMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(value.cast<String, dynamic>());
  }

  String? _contentTypeOf(Object? value) {
    final content = _asMap(value);
    return content?['@type']?.toString();
  }

  String _joinSummaryParts(List<String> parts) {
    if (parts.isEmpty) {
      return 'payload=empty';
    }
    return parts.join(' ');
  }

  String _truncate(String value, {int maxLength = 180}) {
    if (value.length <= maxLength) {
      return value;
    }
    return '${value.substring(0, maxLength - 3)}...';
  }
}
