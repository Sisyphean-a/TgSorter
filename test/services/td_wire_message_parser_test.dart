import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

void main() {
  group('TD wire message parser', () {
    test('parses text/photo/video/audio/document-video/unsupported messages', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': '1',
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
                      'type': 's',
                      'width': 90,
                      'height': 90,
                      'photo': {
                        'id': '10',
                        'local': {'path': '/tmp/p-small.jpg'},
                      },
                    },
                    {
                      'type': 'x',
                      'width': 1280,
                      'height': 720,
                      'photo': {
                        'id': '11',
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
                  'duration': '9',
                  'thumbnail': {
                    'file': {
                      'id': '31',
                      'local': {'path': '/tmp/t.jpg'},
                    },
                  },
                  'video': {
                    'id': '32',
                    'local': {'path': '/tmp/v.mp4'},
                  },
                },
              },
            },
            {
              'id': 4,
              'content': {
                '@type': 'messageAudio',
                'caption': {'text': '', 'entities': []},
                'audio': {
                  'duration': 180,
                  'file_name': 'track.mp3',
                  'title': 'Song',
                  'performer': 'Artist',
                  'audio': {
                    'id': '41',
                    'local': {'path': '/tmp/track.mp3'},
                  },
                },
              },
            },
            {
              'id': 5,
              'content': {
                '@type': 'messageDocument',
                'caption': {'text': '', 'entities': []},
                'document': {
                  'file_name': 'clip.mp4',
                  'mime_type': 'video/mp4',
                  'thumbnail': {
                    'width': 320,
                    'height': 180,
                    'file': {
                      'id': '51',
                      'local': {'path': '/tmp/d-thumb.jpg'},
                    },
                  },
                  'document': {
                    'id': '52',
                    'local': {'path': '/tmp/d-video.mp4'},
                  },
                },
              },
            },
            {
              'id': 6,
              'content': {'@type': 'messagePoll'},
            },
          ],
        }),
      );

      expect(dto.messages[0].content.kind, TdMessageContentKind.text);
      expect(dto.messages[1].content.kind, TdMessageContentKind.photo);
      expect(dto.messages[1].content.localImagePath, '/tmp/p-small.jpg');
      expect(dto.messages[1].content.remoteImageFileId, 10);
      expect(dto.messages[1].content.fullImagePath, '/tmp/p.jpg');
      expect(dto.messages[1].content.remoteFullImageFileId, 11);
      expect(dto.messages[2].content.kind, TdMessageContentKind.video);
      expect(dto.messages[2].content.localVideoPath, '/tmp/v.mp4');
      expect(dto.messages[2].content.localVideoThumbnailPath, '/tmp/t.jpg');
      expect(dto.messages[2].content.remoteVideoFileId, 32);
      expect(dto.messages[2].content.remoteVideoThumbnailFileId, 31);
      expect(dto.messages[2].content.videoDurationSeconds, 9);
      expect(dto.messages[3].content.kind, TdMessageContentKind.audio);
      expect(dto.messages[3].content.localAudioPath, '/tmp/track.mp3');
      expect(dto.messages[3].content.remoteAudioFileId, 41);
      expect(dto.messages[3].content.audioDurationSeconds, 180);
      expect(dto.messages[3].content.fileName, 'track.mp3');
      expect(dto.messages[4].content.kind, TdMessageContentKind.video);
      expect(dto.messages[4].content.localVideoPath, '/tmp/d-video.mp4');
      expect(dto.messages[4].content.localVideoThumbnailPath, '/tmp/d-thumb.jpg');
      expect(dto.messages[5].content.kind, TdMessageContentKind.unsupported);
    });

    test('parses text message web page preview', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': 7,
              'content': {
                '@type': 'messageText',
                'text': {'text': 'https://example.com', 'entities': []},
                'web_page': {
                  'url': 'https://example.com',
                  'display_url': 'example.com',
                  'site_name': 'Example',
                  'title': 'Example Title',
                  'description': {'text': 'Example Description', 'entities': []},
                  'photo': {
                    'sizes': [
                      {
                        'type': 's',
                        'width': 90,
                        'height': 90,
                        'photo': {
                          'id': '71',
                          'local': {'path': '/tmp/example.jpg'},
                        },
                      },
                    ],
                  },
                },
              },
            },
          ],
        }),
      );

      expect(dto.messages.single.content.linkPreview?.url, 'https://example.com');
      expect(dto.messages.single.content.linkPreview?.title, 'Example Title');
      expect(
        dto.messages.single.content.linkPreview?.localImagePath,
        '/tmp/example.jpg',
      );
    });

    test('parses voice note metadata and local file path', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': 6,
              'content': {
                '@type': 'messageVoiceNote',
                'caption': {'text': '', 'entities': []},
                'voice_note': {
                  'duration': 12,
                  'voice': {
                    'id': '61',
                    'local': {'path': '/tmp/voice.ogg'},
                  },
                },
              },
            },
          ],
        }),
      );

      expect(dto.messages.single.content.kind, TdMessageContentKind.audio);
      expect(dto.messages.single.content.localAudioPath, '/tmp/voice.ogg');
      expect(dto.messages.single.content.remoteAudioFileId, 61);
      expect(dto.messages.single.content.audioDurationSeconds, 12);
    });

    test('does not expose local video path before file download completes', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': 5,
              'content': {
                '@type': 'messageVideo',
                'caption': {'text': '', 'entities': []},
                'video': {
                  'duration': 20,
                  'thumbnail': {
                    'file': {
                      'id': '51',
                      'local': {
                        'path': 'C:/tdlib/files/temp/thumb.jpg',
                        'is_downloading_completed': false,
                      },
                    },
                  },
                  'video': {
                    'id': '52',
                    'local': {
                      'path': 'C:/tdlib/files/temp/video.mp4',
                      'is_downloading_completed': false,
                    },
                  },
                },
              },
            },
          ],
        }),
      );

      expect(dto.messages.single.content.localVideoPath, isNull);
      expect(dto.messages.single.content.localVideoThumbnailPath, isNull);
    });

    test('parses forwardMessages result first target message id', () {
      final dto = TdMessagesDto.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'messages',
          'messages': [
            {
              'id': '777',
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
