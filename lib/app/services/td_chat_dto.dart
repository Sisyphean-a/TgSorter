import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

class TdChatListDto {
  const TdChatListDto({required this.chatIds});

  factory TdChatListDto.fromEnvelope(TdWireEnvelope envelope) {
    final rawItems = TdResponseReader.readList(envelope.payload, 'chat_ids');
    return TdChatListDto(
      chatIds: rawItems
          .map(
            (item) => TdResponseReader.readInt(<String, dynamic>{
              'item': item,
            }, 'item'),
          )
          .toList(growable: false),
    );
  }

  final List<int> chatIds;
}

class TdChatDto {
  const TdChatDto({required this.id, required this.title, required this.type});

  factory TdChatDto.fromEnvelope(TdWireEnvelope envelope) {
    final type = TdResponseReader.readMap(envelope.payload, 'type');
    return TdChatDto(
      id: TdResponseReader.readInt(envelope.payload, 'id'),
      title: TdResponseReader.readString(
        envelope.payload,
        'title',
        allowEmpty: true,
      ),
      type: TdResponseReader.readString(type, '@type'),
    );
  }

  final int id;
  final String title;
  final String type;

  bool get isSelectable =>
      type == 'chatTypeBasicGroup' || type == 'chatTypeSupergroup';
}

class TdSelfDto {
  const TdSelfDto({required this.id});

  factory TdSelfDto.fromEnvelope(TdWireEnvelope envelope) {
    return TdSelfDto(id: TdResponseReader.readInt(envelope.payload, 'id'));
  }

  final int id;
}

class TdOptionMyIdDto {
  const TdOptionMyIdDto({required this.value});

  factory TdOptionMyIdDto.fromEnvelope(TdWireEnvelope envelope) {
    return TdOptionMyIdDto(
      value: TdResponseReader.readInt(envelope.payload, 'value'),
    );
  }

  final int value;
}
