import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

void main() {
  group('TD wire message parser', () {
    test('parses text/photo/video/unsupported messages', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': 1,
              'content': {
                '@type': 'messageText',
                'text': {'text': 'hello', 'entities': []},
              },
            },
            {
              'id': 2,
              'content': {
                '@type': 'messagePhoto',
                'caption': {'text': '', 'entities': []},
                'photo': {
                  'sizes': [
                    {
                      'photo': {
                        'id': 11,
                        'local': {'path': '/tmp/p.jpg'},
                      },
                    },
                  ],
                },
              },
            },
            {
              'id': 3,
              'content': {
                '@type': 'messageVideo',
                'caption': {'text': '', 'entities': []},
                'video': {
                  'duration': 9,
                  'thumbnail': {
                    'file': {
                      'id': 31,
                      'local': {'path': '/tmp/t.jpg'},
                    },
                  },
                  'video': {
                    'id': 32,
                    'local': {'path': '/tmp/v.mp4'},
                  },
                },
              },
            },
            {
              'id': 4,
              'content': {'@type': 'messagePoll'},
            },
          ],
        }),
      );

      expect(dto.messages[0].content.kind, TdMessageContentKind.text);
      expect(dto.messages[1].content.kind, TdMessageContentKind.photo);
      expect(dto.messages[1].content.localImagePath, '/tmp/p.jpg');
      expect(dto.messages[1].content.remoteImageFileId, 11);
      expect(dto.messages[2].content.kind, TdMessageContentKind.video);
      expect(dto.messages[2].content.localVideoPath, '/tmp/v.mp4');
      expect(dto.messages[2].content.localVideoThumbnailPath, '/tmp/t.jpg');
      expect(dto.messages[2].content.remoteVideoFileId, 32);
      expect(dto.messages[2].content.remoteVideoThumbnailFileId, 31);
      expect(dto.messages[2].content.videoDurationSeconds, 9);
      expect(dto.messages[3].content.kind, TdMessageContentKind.unsupported);
    });

    test('parses forwardMessages result first target message id', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': 777,
              'content': {
                '@type': 'messageText',
                'text': {'text': 'ok', 'entities': []},
              },
            },
          ],
        }),
      );

      expect(dto.messages.first.id, 777);
    });
  });
}
