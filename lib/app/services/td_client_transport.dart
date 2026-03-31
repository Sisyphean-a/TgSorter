import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';

class TdClientTransport {
  static const Duration _pollInterval = Duration(milliseconds: 16);
  static const double _nonBlockingReceiveTimeoutSeconds = 0;
  static const int _maxEventsPerTick = 64;
  static const int _minimalTdlibLogLevel = 0;

  TdClientTransport();

  final _updatesController = StreamController<TdObject>.broadcast();
  final Map<String, Completer<TdObject>> _pending = {};

  bool _running = false;
  bool _polling = false;
  int? _clientId;
  Timer? _pollTimer;

  Stream<TdObject> get updates => _updatesController.stream;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _clientId = tdCreate();
    if (_clientId == null || _clientId == 0) {
      throw StateError('TDLib 客户端创建失败');
    }
    _running = true;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
    _setTdlibLogLevelAsync();
  }

  Future<void> stop() async {
    _running = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    for (final entry in _pending.values) {
      if (!entry.isCompleted) {
        entry.completeError(StateError('TDLib 客户端已停止'));
      }
    }
    _pending.clear();
  }

  Future<TdObject> send(TdFunction function) async {
    return sendWithTimeout(function, const Duration(seconds: 20));
  }

  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    final clientId = _clientId;
    if (!_running || clientId == null) {
      throw StateError('TDLib 客户端尚未启动');
    }

    final extra = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<TdObject>();
    _pending[extra] = completer;
    tdSend(clientId, function, extra);

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(extra);
        throw TimeoutException('TDLib 请求超时: ${function.getConstructor()}');
      },
    );
  }

  void _pollOnce() {
    if (!_running || _polling) {
      return;
    }
    _polling = true;
    try {
      var processed = 0;
      while (_running && processed < _maxEventsPerTick) {
        final event = tdReceive(_nonBlockingReceiveTimeoutSeconds);
        if (event == null) {
          return;
        }
        processed++;
        _handleEvent(event);
      }
    } catch (error, stack) {
      _updatesController.addError(error, stack);
    } finally {
      _polling = false;
    }
  }

  void _handleEvent(TdObject event) {
    _updatesController.add(event);
    final key = event.extra?.toString();
    if (key == null) {
      return;
    }
    final completer = _pending.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(event);
    }
  }

  void _setTdlibLogLevelAsync() {
    final clientId = _clientId;
    if (clientId == null) {
      return;
    }
    tdSend(
      clientId,
      const SetLogVerbosityLevel(newVerbosityLevel: _minimalTdlibLogLevel),
    );
  }
}
