import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';

void main() {
  test('loadChats delegates to session query gateway', () async {
    final gateway = _FakeSessionQueryGateway();
    final loader = SettingsChatLoader(sessionQueryGateway: gateway);

    final chats = await loader.loadChats();

    expect(gateway.calls, 1);
    expect(chats, hasLength(1));
    expect(chats.single.title, '频道一');
  });
}

class _FakeSessionQueryGateway implements SessionQueryGateway {
  int calls = 0;

  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    calls++;
    return const [SelectableChat(id: -1001, title: '频道一')];
  }
}
