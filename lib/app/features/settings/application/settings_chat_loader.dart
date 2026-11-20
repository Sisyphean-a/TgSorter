import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';

class SettingsChatLoader {
  SettingsChatLoader({required this._sessionQueryGateway});

  final SessionQueryGateway _sessionQueryGateway;

  Future<List<SelectableChat>> loadChats() {
    return _sessionQueryGateway.listSelectableChats();
  }
}
