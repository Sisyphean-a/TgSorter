import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class TdlibRequestExecutor {
  const TdlibRequestExecutor({required TdTransport transport})
    : _transport = transport;

  final TdTransport _transport;

  Future<TdObject> send(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    required Duration timeout,
  }) async {
    try {
      final object = await _transport.sendWithTimeout(function, timeout);
      return _assertNoError(object, request: request, phase: phase);
    } on TimeoutException catch (error, stackTrace) {
      throw TdlibFailure.timeout(
        request: request,
        phase: phase,
        message: 'TDLib request timeout',
        cause: error,
        stackTrace: stackTrace,
      );
    } on TdlibFailure {
      rethrow;
    } catch (error, stackTrace) {
      throw TdlibFailure.transport(
        message: error.toString(),
        request: request,
        phase: phase,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> sendExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    required Duration timeout,
  }) async {
    final object = await send(
      function,
      request: request,
      phase: phase,
      timeout: timeout,
    );
    if (object is! Ok) {
      throw StateError('请求返回非 Ok: ${object.getConstructor()}');
    }
  }

  TdObject _assertNoError(
    TdObject object, {
    required String request,
    required TdlibPhase phase,
  }) {
    if (object is! TdError) {
      return object;
    }
    throw TdlibFailure.tdError(
      code: object.code,
      message: object.message,
      request: request,
      phase: phase,
    );
  }
}
