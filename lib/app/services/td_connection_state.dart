import 'package:tdlib/td_api.dart';

enum TdConnectionStateKind {
  waitingForNetwork,
  connectingToProxy,
  connecting,
  updating,
  ready,
  unknown,
}

class TdConnectionState {
  const TdConnectionState({required this.kind, required this.rawType});

  factory TdConnectionState.fromTdObject(TdObject state) {
    if (state is ConnectionStateWaitingForNetwork) {
      return const TdConnectionState(
        kind: TdConnectionStateKind.waitingForNetwork,
        rawType: 'connectionStateWaitingForNetwork',
      );
    }
    if (state is ConnectionStateConnectingToProxy) {
      return const TdConnectionState(
        kind: TdConnectionStateKind.connectingToProxy,
        rawType: 'connectionStateConnectingToProxy',
      );
    }
    if (state is ConnectionStateConnecting) {
      return const TdConnectionState(
        kind: TdConnectionStateKind.connecting,
        rawType: 'connectionStateConnecting',
      );
    }
    if (state is ConnectionStateUpdating) {
      return const TdConnectionState(
        kind: TdConnectionStateKind.updating,
        rawType: 'connectionStateUpdating',
      );
    }
    if (state is ConnectionStateReady) {
      return const TdConnectionState(
        kind: TdConnectionStateKind.ready,
        rawType: 'connectionStateReady',
      );
    }
    return TdConnectionState(
      kind: TdConnectionStateKind.unknown,
      rawType: state.getConstructor(),
    );
  }

  final TdConnectionStateKind kind;
  final String rawType;

  bool get isReady => kind == TdConnectionStateKind.ready;
}
