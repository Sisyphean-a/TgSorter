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

  factory TdConnectionState.fromJson(Map<String, dynamic> payload) {
    final rawType = payload['@type']?.toString() ?? 'unknown';
    return TdConnectionState(
      kind: switch (rawType) {
        'connectionStateWaitingForNetwork' =>
          TdConnectionStateKind.waitingForNetwork,
        'connectionStateConnectingToProxy' =>
          TdConnectionStateKind.connectingToProxy,
        'connectionStateConnecting' => TdConnectionStateKind.connecting,
        'connectionStateUpdating' => TdConnectionStateKind.updating,
        'connectionStateReady' => TdConnectionStateKind.ready,
        _ => TdConnectionStateKind.unknown,
      },
      rawType: rawType,
    );
  }

  factory TdConnectionState.fromTdObject(TdObject state) {
    return TdConnectionState.fromJson(<String, dynamic>{
      '@type': state.getConstructor(),
    });
  }

  final TdConnectionStateKind kind;
  final String rawType;

  bool get isReady => kind == TdConnectionStateKind.ready;
}
