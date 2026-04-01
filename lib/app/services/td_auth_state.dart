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

  factory TdAuthState.fromTdObject(TdObject state) {
    if (state is AuthorizationStateWaitPhoneNumber) {
      return const TdAuthState(
        kind: TdAuthStateKind.waitPhoneNumber,
        rawType: 'authorizationStateWaitPhoneNumber',
      );
    }
    if (state is AuthorizationStateWaitCode) {
      return const TdAuthState(
        kind: TdAuthStateKind.waitCode,
        rawType: 'authorizationStateWaitCode',
      );
    }
    if (state is AuthorizationStateWaitPassword) {
      return const TdAuthState(
        kind: TdAuthStateKind.waitPassword,
        rawType: 'authorizationStateWaitPassword',
      );
    }
    if (state is AuthorizationStateWaitTdlibParameters) {
      return const TdAuthState(
        kind: TdAuthStateKind.waitTdlibParameters,
        rawType: 'authorizationStateWaitTdlibParameters',
      );
    }
    if (state is AuthorizationStateReady) {
      return const TdAuthState(
        kind: TdAuthStateKind.ready,
        rawType: 'authorizationStateReady',
      );
    }
    if (state is AuthorizationStateClosed) {
      return const TdAuthState(
        kind: TdAuthStateKind.closed,
        rawType: 'authorizationStateClosed',
      );
    }
    return TdAuthState(
      kind: TdAuthStateKind.unknown,
      rawType: state.getConstructor(),
    );
  }

  final TdAuthStateKind kind;
  final String rawType;

  bool get isReady => kind == TdAuthStateKind.ready;
  bool get isClosed => kind == TdAuthStateKind.closed;
  bool get needsTdlibParameters => kind == TdAuthStateKind.waitTdlibParameters;
}
