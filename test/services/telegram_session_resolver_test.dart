import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';
import 'package:tgsorter/app/services/telegram_session_resolver.dart';

void main() {
  group('TelegramSessionResolver', () {
    test(
      'resolveSourceChatId returns explicit source chat id directly',
      () async {
        final adapter = _FakeTdlibAdapter();
        final resolver = TelegramSessionResolver(adapter: adapter);

        final chatId = await resolver.resolveSourceChatId(777);

        expect(chatId, 777);
        expect(adapter.sentConstructors, isEmpty);
      },
    );

    test('resolveSourceChatId resolves and caches self chat id', () async {
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
        },
      );
      final resolver = TelegramSessionResolver(adapter: adapter);

      final first = await resolver.resolveSourceChatId(null);
      final second = await resolver.resolveSourceChatId(null);

      expect(first, 1234567890123);
      expect(second, 1234567890123);
      expect(adapter.createPrivateChatCalls, 1);
    });

    test(
      'listSelectableChats loads main chats and filters selectable chats',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: <String, List<TdWireEnvelope>>{
            'getChats': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'chats',
                'chat_ids': [30, 10, 20, 40],
              }),
            ],
            'getChat': <TdWireEnvelope>[
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'chat',
                'id': 30,
                'title': 'Zoo',
                'type': {'@type': 'chatTypeSupergroup'},
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'chat',
                'id': 10,
                'title': '自己',
                'type': {'@type': 'chatTypePrivate'},
              }),
              TdWireEnvelope.fromJson(<String, dynamic>{
                '@type': 'chat',
                'id': 20,
                'title': 'Alpha',
                'type': {'@type': 'chatTypeBasicGroup'},
              }),
            ],
          },
          expectOkResponses: <String, List<Object?>>{
            'loadChats': <Object?>[
              null,
              TdlibFailure.tdError(
                code: 404,
                message: 'Have no chats to load',
                request: 'loadChats(main)',
                phase: TdlibPhase.business,
              ),
            ],
          },
        );
        final resolver = TelegramSessionResolver(adapter: adapter);

        final chats = await resolver.listSelectableChats();

        expect(adapter.loadChatsCalls, 2);
        expect(chats.map((item) => item.id), [20, 30]);
        expect(chats.map((item) => item.title), ['Alpha', 'Zoo']);
      },
    );
  });
}

class _FakeTdlibAdapter extends TdlibAdapter {
  _FakeTdlibAdapter({
    Map<String, List<TdWireEnvelope>>? wireResponses,
    Map<String, List<Object?>>? expectOkResponses,
  }) : wireResponses = wireResponses ?? <String, List<TdWireEnvelope>>{},
       expectOkResponses = expectOkResponses ?? <String, List<Object?>>{},
       super(
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
  final Map<String, List<Object?>> expectOkResponses;
  final List<String> sentConstructors = <String>[];
  int createPrivateChatCalls = 0;
  int loadChatsCalls = 0;

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
    sentConstructors.add(constructor);
    if (function is CreatePrivateChat) {
      createPrivateChatCalls++;
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
    final constructor = function.getConstructor();
    if (function is LoadChats) {
      loadChatsCalls++;
    }

    final queue = expectOkResponses[constructor];
    if (queue == null || queue.isEmpty) {
      return;
    }

    final next = queue.removeAt(0);
    if (next is Exception) {
      throw next;
    }
  }
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
