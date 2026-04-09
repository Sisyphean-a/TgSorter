import 'package:tdlib/td_api.dart';

enum TdAuthStateKind {
  waitPhoneNumber,
  waitCode,
  waitPassword,
  waitTdlibParameters,
  ready,
  closed,
  unknown,
}

class TdAuthState {
  const TdAuthState({required this.kind, required this.rawType});

  factory TdAuthState.fromJson(Map<String, dynamic> payload) {
    final rawType = payload['@type']?.toString() ?? 'unknown';
    return TdAuthState(
      kind: switch (rawType) {
        'authorizationStateWaitPhoneNumber' => TdAuthStateKind.waitPhoneNumber,
        'authorizationStateWaitCode' => TdAuthStateKind.waitCode,
        'authorizationStateWaitPassword' => TdAuthStateKind.waitPassword,
        'authorizationStateWaitTdlibParameters' =>
          TdAuthStateKind.waitTdlibParameters,
        'authorizationStateReady' => TdAuthStateKind.ready,
        'authorizationStateClosed' => TdAuthStateKind.closed,
        _ => TdAuthStateKind.unknown,
      },
      rawType: rawType,
    );
  }

  factory TdAuthState.fromTdObject(TdObject state) {
    return TdAuthState.fromJson(<String, dynamic>{
      '@type': state.getConstructor(),
    });
  }

  final TdAuthStateKind kind;
  final String rawType;

  bool get isReady => kind == TdAuthStateKind.ready;
  bool get isClosed => kind == TdAuthStateKind.closed;
  bool get needsTdlibParameters => kind == TdAuthStateKind.waitTdlibParameters;
}
