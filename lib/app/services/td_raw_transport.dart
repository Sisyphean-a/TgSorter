import 'dart:async';
import 'dart:convert';

import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';

import 'td_json_logger.dart';

typedef TdPluginProvider = TdPlugin Function();
typedef TdNowMicros = int Function();

class TdRawTransport {
  TdRawTransport({
    TdPlugin? plugin,
    TdPluginProvider? pluginProvider,
    TdJsonLogger? logger,
    Duration pollInterval = _defaultPollInterval,
    TdNowMicros? nowMicros,
  }) : _pluginProvider = pluginProvider ?? (() => plugin ?? TdPlugin.instance),
       _logger = logger ?? TdJsonLogger(),
       _pollInterval = pollInterval,
       _nowMicros = nowMicros ?? _defaultNowMicros;

  static const Duration _defaultPollInterval = Duration(milliseconds: 16);
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const double _nonBlockingReceiveTimeoutSeconds = 0;
  static const int _minimalTdlibLogLevel = 0;

  final TdPluginProvider _pluginProvider;
  final TdJsonLogger _logger;
  final Duration _pollInterval;
  final TdNowMicros _nowMicros;
  final StreamController<Map<String, dynamic>> _updatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pending =
      <String, Completer<Map<String, dynamic>>>{};

  static int _defaultNowMicros() => DateTime.now().microsecondsSinceEpoch;

  bool _running = false;
  bool _polling = false;
  int? _clientId;
  Timer? _pollTimer;
  int _requestSequence = 0;

  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  Future<void> start() async {
    if (_running) {
      return;
    }
    final clientId = _plugin.tdCreate();
    if (clientId == 0) {
      throw StateError('TDLib 客户端创建失败');
    }
    _clientId = clientId;
    _running = true;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
    _setTdlibLogLevel();
  }

  Future<void> stop() async {
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TDLib 客户端已停止'));
      }
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> send(
    TdFunction function, {
    Duration timeout = _defaultTimeout,
  }) {
    final clientId = _requireClientId();
    final extra = _nextExtra();
    if (_pending.containsKey(extra)) {
      throw StateError('TDLib request extra collision: $extra');
    }
    final payload = _buildPayload(function, extra);
    final completer = Completer<Map<String, dynamic>>();
    _pending[extra] = completer;
    _logger.logSend(
      request: function.getConstructor(),
      extra: extra,
      payload: payload,
    );
    _plugin.tdSend(clientId, jsonEncode(payload));
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(extra);
        throw TimeoutException('TDLib 请求超时: ${function.getConstructor()}');
      },
    );
  }

  void sendWithoutResponse(TdFunction function) {
    final clientId = _requireClientId();
    final payload = _buildPayload(function, null);
    _logger.logSend(
      request: function.getConstructor(),
      extra: payload['@extra'],
      payload: payload,
    );
    _plugin.tdSend(clientId, jsonEncode(payload));
  }

  int _requireClientId() {
    final clientId = _clientId;
    if (!_running || clientId == null) {
      throw StateError('TDLib 客户端尚未启动');
    }
    return clientId;
  }

  Map<String, dynamic> _buildPayload(TdFunction function, String? extra) {
    return Map<String, dynamic>.from(function.toJson(extra));
  }

  String _nextExtra() {
    _requestSequence++;
    return '${_nowMicros()}-$_requestSequence';
  }

  TdPlugin get _plugin => _pluginProvider();

  void _pollOnce() {
    if (!_running || _polling) {
      return;
    }
    _polling = true;
    try {
      while (_running) {
        final event = _plugin.tdReceive(_nonBlockingReceiveTimeoutSeconds);
        if (event == null) {
          return;
        }
        _handleRawEvent(event);
      }
    } finally {
      _polling = false;
    }
  }

  void _handleRawEvent(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        throw const FormatException('TDLib payload is not a JSON object');
      }
      final payload = Map<String, dynamic>.from(decoded.cast<String, dynamic>());
      _routePayload(payload);
    } catch (error, stackTrace) {
      _logger.logParseError(
        stage: 'raw_receive',
        payload: rawPayload,
        reason: error.toString(),
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _routePayload(Map<String, dynamic> payload) {
    final type = payload['@type']?.toString() ?? 'unknown';
    final extra = payload['@extra']?.toString();
    final completer = extra == null ? null : _pending.remove(extra);
    if (completer != null) {
      _logger.logReceive(type: type, extra: extra, payload: payload);
      if (!completer.isCompleted) {
        completer.complete(payload);
      }
      return;
    }
    _logger.logUpdate(type: type, payload: payload);
    _updatesController.add(payload);
  }

  void _setTdlibLogLevel() {
    final clientId = _clientId;
    if (clientId == null) {
      return;
    }
    final request = const SetLogVerbosityLevel(
      newVerbosityLevel: _minimalTdlibLogLevel,
    );
    _plugin.tdSend(clientId, jsonEncode(request.toJson()));
  }
}
