import 'dart:ui';

typedef TdlibClose = Future<void> Function();

class TdlibAppExitCoordinator {
  TdlibAppExitCoordinator({required TdlibClose close}) : _close = close;

  final TdlibClose _close;
  Future<AppExitResponse>? _exitTask;

  Future<AppExitResponse> requestExit() {
    final inFlight = _exitTask;
    if (inFlight != null) {
      return inFlight;
    }
    final task = _closeAndExit();
    _exitTask = task;
    return task;
  }

  Future<AppExitResponse> _closeAndExit() async {
    try {
      await _close();
      return AppExitResponse.exit;
    } catch (_) {
      return AppExitResponse.cancel;
    } finally {
      _exitTask = null;
    }
  }
}
