import 'package:tgsorter/app/features/settings/application/session_query_gateway.dart';

class SettingsChatLoader {
  SettingsChatLoader({required SessionQueryGateway sessionQueryGateway})
    : _sessionQueryGateway = sessionQueryGateway;

  final SessionQueryGateway _sessionQueryGateway;

  Future<List<SelectableChat>> loadChats() {
    return _sessionQueryGateway.listSelectableChats();
  }
}
