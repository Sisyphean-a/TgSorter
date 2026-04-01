import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

void main() {
  group('TdlibAdapter startup state machine', () {
    test(
      'runs init to auth when authorization waits for tdlib params',
      () async {
        final calls = <String>[];
        final transport = _FakeTransport(
          responses: <String, List<TdObject>>{
            'getAuthorizationState': <TdObject>[
              const AuthorizationStateWaitTdlibParameters(),
            ],
            'setTdlibParameters': <TdObject>[const Ok()],
            'addProxy': <TdObject>[const Ok()],
          },
        );
        final adapter = TdlibAdapter(
          transport: transport,
          credentials: const TdlibCredentials(
            apiId: 1,
            apiHash: 'hash',
            proxyServer: '127.0.0.1',
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
            server: '127.0.0.1',
            port: 1080,
            username: '',
            password: '',
          ),
          detectCapabilities: () async {
            calls.add('detectCapabilities');
            expect(
              transport.requestConstructors,
              contains('setTdlibParameters'),
            );
            return const TdlibSchemaCapabilities(
              addProxyMode: TdlibAddProxyMode.flatArgs,
            );
          },
          initializeTdlib: (_) async {},
        );
        final states = <TdlibStartupState>[];
        final sub = adapter.startupStates.listen(states.add);

        await adapter.start();

        expect(states, <TdlibStartupState>[
          TdlibStartupState.init,
          TdlibStartupState.setParams,
          TdlibStartupState.setProxy,
          TdlibStartupState.auth,
        ]);
        expect(transport.requestConstructors, <String>[
          'getAuthorizationState',
          'setTdlibParameters',
          'addProxy',
        ]);
        expect(calls, ['detectCapabilities']);
        await sub.cancel();
      },
    );

    test('enters ready when startup sees authorization ready', () async {
      final transport = _FakeTransport(
        responses: <String, List<TdObject>>{
          'getAuthorizationState': <TdObject>[const AuthorizationStateReady()],
          'disableProxy': <TdObject>[const Ok()],
        },
      );
      final adapter = TdlibAdapter(
        transport: transport,
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
      final states = <TdlibStartupState>[];
      final sub = adapter.startupStates.listen(states.add);

      await adapter.start();

      expect(states.last, TdlibStartupState.ready);
      await sub.cancel();
    });
  });
}

class _FakeTransport implements TdTransport {
  _FakeTransport({required Map<String, List<TdObject>> responses})
    : _responses = responses;

  final Map<String, List<TdObject>> _responses;
  final StreamController<TdObject> _updates =
      StreamController<TdObject>.broadcast();
  final List<String> requestConstructors = <String>[];

  @override
  Stream<TdObject> get updates => _updates.stream;

  @override
  Future<void> start() async {}

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
    requestConstructors.add(function.getConstructor());
  }

  @override
  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    final constructor = function.getConstructor();
    requestConstructors.add(constructor);
    final queue = _responses[constructor];
    if (queue == null || queue.isEmpty) {
      throw StateError('Missing fake response for $constructor');
    }
    return queue.removeAt(0);
  }
}
