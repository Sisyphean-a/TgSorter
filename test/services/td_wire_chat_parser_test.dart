import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_chat_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

void main() {
  group('TD wire chat parser', () {
    test('parses getChats response', () {
      final dto = TdChatListDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'chats',
          'chat_ids': [1, '2', 3],
        }),
      );

      expect(dto.chatIds, [1, 2, 3]);
    });

    test('parses getChat response', () {
      final dto = TdChatDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'chat',
          'id': 10,
          'title': 'Group A',
          'type': <String, dynamic>{'@type': 'chatTypeSupergroup'},
        }),
      );

      expect(dto.id, 10);
      expect(dto.title, 'Group A');
      expect(dto.isSelectable, isTrue);
    });

    test('parses getMe and getOption(my_id) responses', () {
      final me = TdSelfDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'user', 'id': 99}),
      );
      final myId = TdOptionMyIdDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'optionValueInteger',
          'value': '88',
        }),
      );

      expect(me.id, 99);
      expect(myId.value, 88);
    });
  });
}
