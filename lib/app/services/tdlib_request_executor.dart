import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

class TdlibRequestExecutor {
  const TdlibRequestExecutor({
    required TdTransport transport,
    TdRawTransport? rawTransport,
  }) : _transport = transport,
       _rawTransport = rawTransport;

  final TdTransport _transport;
  final TdRawTransport? _rawTransport;

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

  Future<void> sendWireExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    required Duration timeout,
  }) async {
    final envelope = await sendWire(
      function,
      request: request,
      phase: phase,
      timeout: timeout,
    );
    if (envelope.type != 'ok') {
      throw StateError('请求返回非 Ok: ${envelope.type}');
    }
  }

  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    required Duration timeout,
  }) async {
    final transport = _rawTransport;
    try {
      final envelope = transport == null
          ? TdWireEnvelope.fromTdObject(
              await _transport.sendWithTimeout(function, timeout),
            )
          : TdWireEnvelope.fromJson(await transport.send(function, timeout: timeout));
      _assertNoWireError(envelope, request: request, phase: phase);
      return envelope;
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

  TdWireEnvelope _assertNoWireError(
    TdWireEnvelope envelope, {
    required String request,
    required TdlibPhase phase,
  }) {
    if (!envelope.isError) {
      return envelope;
    }
    final error = TdWireError.fromEnvelope(envelope);
    throw TdlibFailure.tdError(
      code: error.code,
      message: error.message,
      request: request,
      phase: phase,
    );
  }
}
