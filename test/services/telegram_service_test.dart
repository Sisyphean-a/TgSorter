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

    test('fetchMessagePage skips duplicate cursor in latestFirst mode', () async {
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
    });

    test('classifyMessage does not delete when forward returns empty', () async {
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
          messageId: 10,
          targetChatId: 999,
        ),
        throwsA(isA<StateError>()),
      );

      expect(adapter.deleteMessageCalls, 0);
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
  int deleteMessageCalls = 0;

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
    final queue = wireResponses[constructor];
    if (queue == null || queue.isEmpty) {
      throw StateError('Missing fake wire response for $constructor');
    }
    return queue.removeAt(0);
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
