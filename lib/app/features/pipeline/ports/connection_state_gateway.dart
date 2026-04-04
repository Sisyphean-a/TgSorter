import 'package:tgsorter/app/services/td_connection_state.dart';

abstract class ConnectionStateGateway {
  Stream<TdConnectionState> get connectionStates;
}
