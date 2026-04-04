import 'package:tgsorter/app/services/telegram_gateway.dart';

/// Settings feature 依赖的最小会话查询能力接口（capability port）。
abstract class SessionQueryGateway {
  Future<List<SelectableChat>> listSelectableChats();
}

