import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';

class TdParsedUpdate {
  const TdParsedUpdate({this.authState, this.connectionState});

  final TdAuthState? authState;
  final TdConnectionState? connectionState;
}

abstract final class TdUpdateParser {
  static TdParsedUpdate parse(Map<String, dynamic> payload) {
    final type = payload['@type']?.toString() ?? 'unknown';
    if (type == 'updateAuthorizationState') {
      final auth = TdResponseReader.readMap(payload, 'authorization_state');
      return TdParsedUpdate(authState: TdAuthState.fromJson(auth));
    }
    if (type == 'updateConnectionState') {
      final state = TdResponseReader.readMap(payload, 'state');
      return TdParsedUpdate(connectionState: TdConnectionState.fromJson(state));
    }
    return const TdParsedUpdate();
  }
}
