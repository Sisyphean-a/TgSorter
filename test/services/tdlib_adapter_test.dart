import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_json_logger.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

void main() {
  group('TdlibAdapter', () {
    test('getProxies returns local proxy dto', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'getProxies': <TdObject>[
            Proxies(
              proxies: [
                Proxy(
                  id: 1,
                  server: '127.0.0.1',
                  port: 1080,
                  lastUsedDate: 0,
                  isEnabled: true,
                  type: const ProxyTypeSocks5(username: '', password: ''),
                ),
              ],
            ),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
      );

      final proxies = await adapter.getProxies();

      expect(proxies.proxies.single.server, '127.0.0.1');
    });

    test('addProxy uses nested proxy request for legacy schema', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'getProxies': <TdObject>[
            Proxies(
              proxies: [
                Proxy(
                  id: 1,
                  server: '10.0.0.1',
                  port: 1080,
                  lastUsedDate: 0,
                  isEnabled: true,
                  type: const ProxyTypeSocks5(username: '', password: ''),
                ),
              ],
            ),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.nestedProxyObject,
        ),
      );

      await adapter.addProxy();

      expect(transport.sentWithoutResponse.single.getConstructor(), 'addProxy');
      expect(
        transport.sentWithoutResponse.single.toJson()['proxy']['server'],
        '10.0.0.1',
      );
    });

    test('addProxy accepts proxy response for flat schema', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'addProxy': <TdObject>[
            Proxy(
              id: 1,
              server: '10.0.0.1',
              port: 1080,
              lastUsedDate: 0,
              isEnabled: true,
              type: const ProxyTypeSocks5(username: '', password: ''),
            ),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
      );

      await adapter.addProxy();

      expect(transport.sentWithoutResponse, isEmpty);
    });

    test('submitPhoneNumber wraps td errors as TdlibFailure', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'setAuthenticationPhoneNumber': <TdObject>[
            TdError(code: 401, message: 'PHONE_NUMBER_INVALID'),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
      );

      expect(
        adapter.submitPhoneNumber('+8613800000000'),
        throwsA(
          isA<TdlibFailure>()
              .having((error) => error.code, 'code', 401)
              .having(
                (error) => error.request,
                'request',
                'setAuthenticationPhoneNumber',
              ),
        ),
      );
    });

    test(
      'forwards raw message send succeeded update through adapter stream',
      () async {
        final transport = _InspectableFakeTransport(
          responses: <String, List<TdObject>>{
            'getAuthorizationState': <TdObject>[
              const AuthorizationStateReady(),
            ],
            'disableProxy': <TdObject>[const Ok()],
          },
        );
        final rawTransport = _InspectableRawTransport();
        final adapter = TdlibAdapter(
          transport: transport,
          rawTransport: rawTransport,
          credentials: const TdlibCredentials(
            apiId: 1,
            apiHash: 'hash',
            proxyServer: null,
            proxyPort: null,
            proxyUsername: '',
            proxyPassword: '',
          ),
          runtimePaths: const TdlibRuntimePaths(
            libraryPath: 'tdjson.dll',
            databaseDirectory: 'db',
            filesDirectory: 'files',
          ),
          readProxySettings: () => const ProxySettings(
            server: '',
            port: null,
            username: '',
            password: '',
          ),
          detectCapabilities: () async => const TdlibSchemaCapabilities(
            addProxyMode: TdlibAddProxyMode.flatArgs,
          ),
          initializeTdlib: (_) async {},
        );

        await rawTransport.start();
        await adapter.start();
        final future = adapter.messageSendResults.first;
        rawTransport.emitUpdate(<String, dynamic>{
          '@type': 'updateMessageSendSucceeded',
          'old_message_id': 77,
          'message': <String, dynamic>{
            '@type': 'message',
            'id': 88,
            'chat_id': 999,
            'content': <String, dynamic>{
              '@type': 'messageText',
              'text': <String, dynamic>{'text': 'ok', 'entities': <Object>[]},
            },
          },
        });

        final result = await future;

        expect(result.chatId, 999);
        expect(result.oldMessageId, 77);
        expect(result.messageId, 88);
        expect(result.isSuccess, isTrue);
      },
    );

    test(
      'forwards raw connection updates emitted during transport start',
      () async {
        final rawTransport = _InspectableRawTransport(
          updatesOnStart: const [
            <String, dynamic>{
              '@type': 'updateConnectionState',
              'state': <String, dynamic>{'@type': 'connectionStateReady'},
            },
          ],
        );
        final transport = _InspectableFakeTransport(
          responses: <String, List<TdObject>>{
            'getAuthorizationState': <TdObject>[
              const AuthorizationStateReady(),
            ],
            'disableProxy': <TdObject>[const Ok()],
          },
          onStart: rawTransport.start,
        );
        final adapter = TdlibAdapter(
          transport: transport,
          rawTransport: rawTransport,
          credentials: const TdlibCredentials(
            apiId: 1,
            apiHash: 'hash',
            proxyServer: null,
            proxyPort: null,
            proxyUsername: '',
            proxyPassword: '',
          ),
          runtimePaths: const TdlibRuntimePaths(
            libraryPath: 'tdjson.dll',
            databaseDirectory: 'db',
            filesDirectory: 'files',
          ),
          readProxySettings: () => const ProxySettings(
            server: '',
            port: null,
            username: '',
            password: '',
          ),
          detectCapabilities: () async => const TdlibSchemaCapabilities(
            addProxyMode: TdlibAddProxyMode.flatArgs,
          ),
          initializeTdlib: (_) async {},
        );

        final connection = adapter.connectionStates.first.timeout(
          const Duration(milliseconds: 20),
        );
        await adapter.start();

        expect((await connection).isReady, isTrue);
      },
    );
  });
}

TdlibAdapter _buildAdapter(
  _InspectableFakeTransport transport, {
  required TdlibSchemaCapabilities capabilities,
}) {
  return TdlibAdapter(
    transport: transport,
    rawTransport: null,
    credentials: const TdlibCredentials(
      apiId: 1,
      apiHash: 'hash',
      proxyServer: '10.0.0.1',
      proxyPort: 1080,
      proxyUsername: '',
      proxyPassword: '',
    ),
    runtimePaths: const TdlibRuntimePaths(
      libraryPath: 'tdjson.dll',
      databaseDirectory: 'db',
      filesDirectory: 'files',
    ),
    readProxySettings: () => const ProxySettings(
      server: '10.0.0.1',
      port: 1080,
      username: '',
      password: '',
    ),
    detectCapabilities: () async => capabilities,
    initializeTdlib: (_) async {},
  );
}

class _InspectableFakeTransport implements TdTransport {
  _InspectableFakeTransport({
    required Map<String, List<TdObject>> responses,
    Future<void> Function()? onStart,
  }) : _responses = responses,
       _onStart = onStart;

  final Map<String, List<TdObject>> _responses;
  final Future<void> Function()? _onStart;
  final StreamController<TdObject> _updates =
      StreamController<TdObject>.broadcast();
  final List<TdFunction> sentWithoutResponse = <TdFunction>[];

  @override
  Stream<TdObject> get updates => _updates.stream;

  @override
  Future<void> start() async {
    await _onStart?.call();
  }

  @override
  Future<void> stop() async {
    await _updates.close();
  }

  @override
  Future<TdObject> send(TdFunction function) async {
    return sendWithTimeout(function, const Duration(seconds: 20));
  }

  @override
  void sendWithoutResponse(TdFunction function) {
    sentWithoutResponse.add(function);
  }

  @override
  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    final queue = _responses[function.getConstructor()];
    if (queue == null || queue.isEmpty) {
      throw StateError(
        'Missing fake response for ${function.getConstructor()}',
      );
    }
    return queue.removeAt(0);
  }
}

class _InspectableRawTransport extends TdRawTransport {
  _InspectableRawTransport({
    List<Map<String, dynamic>> updatesOnStart = const <Map<String, dynamic>>[],
  }) : _updatesOnStart = updatesOnStart,
       _updatesController = StreamController<Map<String, dynamic>>.broadcast(),
       _responses = <String, List<Map<String, dynamic>>>{
         'disableProxy': <Map<String, dynamic>>[
           <String, dynamic>{'@type': 'ok'},
         ],
       },
       super(logger: TdJsonLogger(isEnabled: false));

  final List<Map<String, dynamic>> _updatesOnStart;
  final StreamController<Map<String, dynamic>> _updatesController;
  final Map<String, List<Map<String, dynamic>>> _responses;
  bool started = false;

  @override
  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  @override
  Future<void> start() async {
    started = true;
    for (final update in _updatesOnStart) {
      emitUpdate(update);
    }
  }

  @override
  Future<void> stop() async {
    started = false;
  }

  @override
  Future<Map<String, dynamic>> send(
    TdFunction function, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final queue = _responses[function.getConstructor()];
    if (queue == null || queue.isEmpty) {
      throw StateError(
        'Missing fake raw response for ${function.getConstructor()}',
      );
    }
    return queue.removeAt(0);
  }

  @override
  void sendWithoutResponse(TdFunction function) {}

  void emitUpdate(Map<String, dynamic> payload) {
    if (!started) {
      throw StateError('transport not started');
    }
    _updatesController.add(payload);
  }
}
