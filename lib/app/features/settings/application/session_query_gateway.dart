import 'package:tgsorter/app/services/telegram_gateway.dart';

abstract class SessionQueryGateway {
  Future<List<SelectableChat>> listSelectableChats();
}
