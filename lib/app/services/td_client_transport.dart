import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';

class TdClientTransport {
  TdClientTransport();

  final _updatesController = StreamController<TdObject>.broadcast();
  final Map<String, Completer<TdObject>> _pending = {};

  bool _running = false;
  int? _clientId;

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
    unawaited(_pumpLoop());
  }

  Future<void> stop() async {
    _running = false;
    for (final entry in _pending.values) {
      if (!entry.isCompleted) {
        entry.completeError(StateError('TDLib 客户端已停止'));
      }
    }
    _pending.clear();
  }

  Future<TdObject> send(TdFunction function) async {
    final clientId = _clientId;
    if (!_running || clientId == null) {
      throw StateError('TDLib 客户端尚未启动');
    }

    final extra = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<TdObject>();
    _pending[extra] = completer;
    tdSend(clientId, function, extra);

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pending.remove(extra);
        throw TimeoutException('TDLib 请求超时: ${function.getConstructor()}');
      },
    );
  }

  Future<void> _pumpLoop() async {
    while (_running) {
      try {
        final event = tdReceive(1.0);
        if (event == null) {
          continue;
        }
        _updatesController.add(event);
        final key = event.extra?.toString();
        if (key == null) {
          continue;
        }
        final completer = _pending.remove(key);
        if (completer != null && !completer.isCompleted) {
          completer.complete(event);
        }
      } catch (error, stack) {
        _updatesController.addError(error, stack);
      }
    }
  }
}
