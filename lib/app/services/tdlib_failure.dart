enum TdlibFailureKind { tdlib, timeout, transport, unexpected }

enum TdlibPhase { startup, auth, business }

class TdlibFailure implements Exception {
  const TdlibFailure({
    required this.kind,
    required this.message,
    required this.phase,
    required this.request,
    this.code,
    this.cause,
    this.stackTrace,
  });

  factory TdlibFailure.tdError({
    required int code,
    required String message,
    required String request,
    required TdlibPhase phase,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return TdlibFailure(
      kind: TdlibFailureKind.tdlib,
      code: code,
      message: message,
      request: request,
      phase: phase,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory TdlibFailure.timeout({
    required String request,
    required TdlibPhase phase,
    required String message,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return TdlibFailure(
      kind: TdlibFailureKind.timeout,
      message: message,
      request: request,
      phase: phase,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory TdlibFailure.transport({
    required String message,
    required String request,
    required TdlibPhase phase,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return TdlibFailure(
      kind: TdlibFailureKind.transport,
      message: message,
      request: request,
      phase: phase,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  final TdlibFailureKind kind;
  final int? code;
  final String message;
  final String request;
  final TdlibPhase phase;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final codeText = code == null ? '' : '($code)';
    return 'TDLib failure$request$codeText: $message';
  }
}
