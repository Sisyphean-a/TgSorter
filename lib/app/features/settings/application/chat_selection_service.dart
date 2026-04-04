import 'session_query_gateway.dart';

class ChatSelectionService {
  ChatSelectionService({required SessionQueryGateway sessionQueryGateway})
    : _sessionQueryGateway = sessionQueryGateway;

  final SessionQueryGateway _sessionQueryGateway;

  Future<List<SelectableChat>> loadChats() {
    return _sessionQueryGateway.listSelectableChats();
  }
}
