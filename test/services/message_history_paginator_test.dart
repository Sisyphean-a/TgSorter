import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/message_history_paginator.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

void main() {
  group('MessageHistoryPaginator', () {
    test(
      'fetchSavedMessagePage removes duplicate cursor item in latestFirst',
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
        final paginator = MessageHistoryPaginator(adapter: adapter);

        final page = await paginator.fetchSavedMessagePage(
          chatId: 777,
          direction: MessageFetchDirection.latestFirst,
          fromMessageId: 10,
          limit: 2,
        );

        expect(page.map((item) => item.id), [9]);
      },
    );

    test(
      'fetchSavedMessagePage returns ascending ids in oldestFirst',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [
                  _textMessageJson(12, 'm12'),
                  _textMessageJson(11, 'm11'),
                ],
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final paginator = MessageHistoryPaginator(adapter: adapter);

        final page = await paginator.fetchSavedMessagePage(
          chatId: 777,
          direction: MessageFetchDirection.oldestFirst,
          fromMessageId: null,
          limit: 2,
        );

        expect(page.map((item) => item.id), [11, 12]);
      },
    );

    test('fetchSavedMessage returns first message for direction', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getChatHistory': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [_textMessageJson(20, 'latest')],
            }),
          ],
        },
      );
      final paginator = MessageHistoryPaginator(adapter: adapter);

      final message = await paginator.fetchSavedMessage(
        chatId: 777,
        direction: MessageFetchDirection.latestFirst,
      );

      expect(message?.id, 20);
    });

    test('fetchAllHistoryMessages reads until empty page', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'getChatHistory': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [
                _textMessageJson(5, 'm5'),
                _textMessageJson(4, 'm4'),
              ],
            }),
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [
                _textMessageJson(3, 'm3'),
                _textMessageJson(2, 'm2'),
              ],
            }),
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [],
            }),
          ],
        },
      );
      final paginator = MessageHistoryPaginator(
        adapter: adapter,
        historyBatchSize: 2,
      );

      final page = await paginator.fetchAllHistoryMessages(777);

      expect(page.map((item) => item.id), [2, 3, 4, 5]);
    });

    test(
      'fetchSavedMessagePage oldestFirst continues across short pages',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChatHistory': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(100 - index, 'm${100 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(80 - index, 'm${80 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(60 - index, 'm${60 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(40 - index, 'm${40 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': List.generate(
                  20,
                  (index) => _textMessageJson(20 - index, 'm${20 - index}'),
                ),
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'messages',
                'messages': [],
              }),
            ],
          },
        );
        final paginator = MessageHistoryPaginator(adapter: adapter);

        final page = await paginator.fetchSavedMessagePage(
          chatId: 777,
          direction: MessageFetchDirection.oldestFirst,
          fromMessageId: null,
          limit: 20,
        );

        expect(
          page.map((item) => item.id),
          List.generate(20, (index) => index + 1),
        );
      },
    );
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

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final queue = wireResponses[function.getConstructor()];
    if (queue == null || queue.isEmpty) {
      throw StateError(
        'Missing fake wire response for ${function.getConstructor()}',
      );
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
