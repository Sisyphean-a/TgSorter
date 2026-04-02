import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

void main() {
  group('TelegramService', () {
    test('fetchNextMessage for video downloads thumbnail only', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getChatHistory': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [
                {
                  'id': 10,
                  'content': {
                    '@type': 'messageVideo',
                    'caption': {'text': '', 'entities': []},
                    'video': {
                      'duration': 12,
                      'thumbnail': {
                        'file': {
                          'id': 31,
                          'local': {'path': ''},
                        },
                      },
                      'video': {
                        'id': 32,
                        'local': {'path': ''},
                      },
                    },
                  },
                },
              ],
            }),
          ],
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final service = TelegramService(adapter: adapter);

      await service.fetchNextMessage(
        direction: MessageFetchDirection.latestFirst,
        sourceChatId: 777,
      );

      expect(adapter.downloadedFileIds, <int>[31]);
    });

    test(
      'fetchMessagePage skips duplicate cursor in latestFirst mode',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _textMessageJson(10, 'first'),
                  _textMessageJson(9, 'second'),
                ],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: 10,
          limit: 2,
        );

        expect(page.map((item) => item.id), [9]);
      },
    );

    test(
      'classifyMessage does not delete when forward returns empty',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await expectLater(
          () => service.classifyMessage(
            sourceChatId: 777,
            messageIds: const [10],
            targetChatId: 999,
            asCopy: false,
          ),
          throwsA(isA<StateError>()),
        );

        expect(adapter.deleteMessageCalls, 0);
      },
    );

    test(
      'classifyMessage uses sendCopy when no-reference mode is enabled',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [_textMessageJson(88, 'copied')],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await service.classifyMessage(
          sourceChatId: 777,
          messageIds: const [10],
          targetChatId: 999,
          asCopy: true,
        );

        expect(adapter.lastForwardSendCopy, isTrue);
      },
    );

    test(
      'classifyMessage deletes with revoke true',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'forwardMessages': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [_textMessageJson(88, 'copied')],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await service.classifyMessage(
          sourceChatId: 777,
          messageIds: const [10],
          targetChatId: 999,
          asCopy: false,
        );

        expect(adapter.deleteMessageRevokes, <bool>[true]);
      },
    );

    test(
      'requireSelfChatId resolves real private chat id via createPrivateChat',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getOption': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'optionValueInteger',
                'value': 1774463496,
              }),
            ],
            'createPrivateChat': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'chat',
                'id': 1234567890123,
                'title': '收藏夹',
                'type': {'@type': 'chatTypePrivate', 'user_id': 1774463496},
              }),
            ],
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        await service.fetchNextMessage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: null,
        );

        expect(adapter.lastHistoryChatId, 1234567890123);
      },
    );

    test(
      'fetchMessagePage groups audio album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _audioMessageJson(12, 'track 2', albumId: '700'),
                  _audioMessageJson(11, 'track 1', albumId: '700'),
                  _textMessageJson(10, 'tail'),
                ],
              }),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 3,
        );

        expect(page.length, 2);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.audioTracks.map((item) => item.title), [
          'track 1',
          'track 2',
        ]);
      },
    );

    test(
      'fetchMessagePage groups photo album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _photoMessageJson(12, albumId: '700'),
                  _photoMessageJson(11, albumId: '700'),
                ],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.mediaItems.length, 2);
      },
    );

    test(
      'fetchMessagePage groups video album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _videoMessageJson(12, albumId: '700'),
                  _videoMessageJson(11, albumId: '700'),
                ],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.mediaItems.length, 2);
      },
    );

    test(
      'fetchMessagePage keeps album messageIds increasing in oldestFirst mode',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _videoMessageJson(12, albumId: '700'),
                  _videoMessageJson(11, albumId: '700'),
                ],
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.oldestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
      },
    );

    test(
      'fetchMessagePage groups document-video album messages into one pipeline item',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _documentVideoMessageJson(12, albumId: '700'),
                  _documentVideoMessageJson(11, albumId: '700'),
                ],
              }),
            ],
            'downloadFile': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
              TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
            ],
          },
        );
        final service = TelegramService(adapter: adapter);

        final page = await service.fetchMessagePage(
          direction: MessageFetchDirection.latestFirst,
          sourceChatId: 777,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.length, 1);
        expect(page.first.messageIds, [11, 12]);
        expect(page.first.preview.mediaItems.length, 2);
      },
    );

    test('prepareMediaPreview downloads thumbnail for video only', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getMessage': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'message',
              'id': 10,
              'chat_id': 777,
              'content': {
                '@type': 'messageVideo',
                'caption': {'text': '', 'entities': []},
                'video': {
                  'duration': 12,
                  'thumbnail': {
                    'file': {
                      'id': 31,
                      'local': {'path': ''},
                    },
                  },
                  'video': {
                    'id': 32,
                    'local': {'path': ''},
                  },
                },
              },
            }),
          ],
          'downloadFile': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{'@type': 'ok'}),
          ],
        },
      );
      final service = TelegramService(adapter: adapter);

      await service.prepareMediaPreview(sourceChatId: 777, messageId: 10);

      expect(adapter.downloadedFileIds, [31]);
    });
  });
}

class _FakeTdlibAdapter extends TdlibAdapter {
  _FakeTdlibAdapter({required this.wireResponses})
    : super(
        transport: _NoopTransport(),
        credentials: const TdlibCredentials(
          apiId: 1,
          apiHash: 'hash',
          proxyServer: null,
          proxyPort: null,
          proxyUsername: '',
          proxyPassword: '',
        ),
        readProxySettings: () => const ProxySettings(
          server: '',
          port: null,
          username: '',
          password: '',
        ),
        runtimePaths: const TdlibRuntimePaths(
          libraryPath: 'tdjson.dll',
          databaseDirectory: 'db',
          filesDirectory: 'files',
        ),
        detectCapabilities: () async => const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
        initializeTdlib: (_) async {},
      );

  final Map<String, List<TdWireEnvelope>> wireResponses;
  final List<int> downloadedFileIds = <int>[];
  final List<bool> deleteMessageRevokes = <bool>[];
  int deleteMessageCalls = 0;
  bool? lastForwardSendCopy;
  int? lastHistoryChatId;

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final constructor = function.getConstructor();
    if (function is DownloadFile) {
      downloadedFileIds.add(function.fileId);
    }
    if (function is DeleteMessages) {
      deleteMessageCalls++;
    }
    if (function is ForwardMessages) {
      lastForwardSendCopy = function.sendCopy;
    }
    if (function is GetChatHistory) {
      lastHistoryChatId = function.chatId;
    }
    final queue = wireResponses[constructor];
    if (queue == null || queue.isEmpty) {
      throw StateError('Missing fake wire response for $constructor');
    }
    return queue.removeAt(0);
  }

  @override
  Future<void> sendWireExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (function is DeleteMessages) {
      deleteMessageRevokes.add(function.revoke);
      deleteMessageCalls++;
      return;
    }
    throw UnimplementedError();
  }
}

Map<String, dynamic> _textMessageJson(int id, String text) {
  return <String, dynamic>{
    'id': id,
    'content': {
      '@type': 'messageText',
      'text': {'text': text, 'entities': []},
    },
  };
}

Map<String, dynamic> _audioMessageJson(
  int id,
  String title, {
  required String albumId,
}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messageAudio',
      'caption': {'text': '', 'entities': []},
      'audio': {
        'duration': 12,
        'title': title,
        'audio': {
          'id': id + 100,
          'local': {'path': ''},
        },
      },
    },
  };
}

Map<String, dynamic> _photoMessageJson(int id, {required String albumId}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
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
              'id': id + 100,
              'local': {'path': ''},
            },
          },
          {
            'type': 'x',
            'width': 1280,
            'height': 720,
            'photo': {
              'id': id + 200,
              'local': {'path': ''},
            },
          },
        ],
      },
    },
  };
}

Map<String, dynamic> _videoMessageJson(int id, {required String albumId}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messageVideo',
      'caption': {'text': '', 'entities': []},
      'video': {
        'duration': 12,
        'thumbnail': {
          'file': {
            'id': id + 100,
            'local': {'path': ''},
          },
        },
        'video': {
          'id': id + 200,
          'local': {'path': ''},
        },
      },
    },
  };
}

Map<String, dynamic> _documentVideoMessageJson(int id, {required String albumId}) {
  return <String, dynamic>{
    'id': id,
    'media_album_id': albumId,
    'content': {
      '@type': 'messageDocument',
      'caption': {'text': '', 'entities': []},
      'document': {
        'file_name': 'clip_$id.mp4',
        'mime_type': 'video/mp4',
        'thumbnail': {
          'width': 320,
          'height': 180,
          'file': {
            'id': id + 100,
            'local': {'path': ''},
          },
        },
        'document': {
          'id': id + 200,
          'local': {'path': ''},
        },
      },
    },
  };
}

class _NoopTransport implements TdTransport {
  @override
  Stream<TdObject> get updates => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<TdObject> send(TdFunction function) async {
    throw UnimplementedError();
  }

  @override
  void sendWithoutResponse(TdFunction function) {}

  @override
  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    throw UnimplementedError();
  }
}
