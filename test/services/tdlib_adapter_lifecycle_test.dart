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
  group('TdlibAdapter lifecycle', () {
    test('stop releases local resources and returns to idle', () async {
      final transport = _LifecycleFakeTransport(
        responses: <String, List<TdObject>>{
          'getAuthorizationState': <TdObject>[const AuthorizationStateReady()],
          'disableProxy': <TdObject>[const Ok()],
        },
      );
      final adapter = _buildAdapter(transport);
      final states = <TdlibLifecycleState>[];
      final sub = adapter.lifecycleStates.listen(states.add);

      await adapter.start();
      await adapter.stop();

      expect(adapter.lifecycleState, TdlibLifecycleState.idle);
      expect(adapter.isRunning, isFalse);
      expect(transport.startCount, 1);
      expect(transport.stopCount, 1);
      expect(
        states,
        containsAllInOrder(<TdlibLifecycleState>[
          TdlibLifecycleState.starting,
          TdlibLifecycleState.running,
          TdlibLifecycleState.stopping,
          TdlibLifecycleState.idle,
        ]),
      );
      await sub.cancel();
    });

    test(
      'close sends close request and enters closed after closed update',
      () async {
        final transport = _LifecycleFakeTransport(
          responses: <String, List<TdObject>>{
            'getAuthorizationState': <TdObject>[
              const AuthorizationStateReady(),
            ],
            'disableProxy': <TdObject>[const Ok()],
            'close': <TdObject>[const Ok()],
          },
          onSend: (constructor, fake) {
            if (constructor != 'close') {
              return;
            }
            fake.emitUpdate(
              UpdateAuthorizationState(
                authorizationState: const AuthorizationStateClosed(),
              ),
            );
          },
        );
        final adapter = _buildAdapter(transport);
        final states = <TdlibLifecycleState>[];
        final sub = adapter.lifecycleStates.listen(states.add);

        await adapter.start();
        await adapter.close();

        expect(adapter.lifecycleState, TdlibLifecycleState.closed);
        expect(adapter.isRunning, isFalse);
        expect(transport.stopCount, 1);
        expect(transport.requestConstructors, contains('close'));
        expect(
          states,
          containsAllInOrder(<TdlibLifecycleState>[
            TdlibLifecycleState.starting,
            TdlibLifecycleState.running,
            TdlibLifecycleState.closing,
            TdlibLifecycleState.closed,
          ]),
        );
        await sub.cancel();
      },
    );

    test('restart performs stop then start again', () async {
      final transport = _LifecycleFakeTransport(
        responses: <String, List<TdObject>>{
          'getAuthorizationState': <TdObject>[
            const AuthorizationStateReady(),
            const AuthorizationStateReady(),
          ],
          'disableProxy': <TdObject>[const Ok(), const Ok()],
        },
      );
      final adapter = _buildAdapter(transport);

      await adapter.start();
      await adapter.restart();

      expect(adapter.lifecycleState, TdlibLifecycleState.running);
      expect(adapter.isRunning, isTrue);
      expect(transport.startCount, 2);
      expect(transport.stopCount, 1);
      expect(
        transport.requestConstructors
            .where((constructor) => constructor == 'getAuthorizationState')
            .length,
        2,
      );
    });
  });
}

TdlibAdapter _buildAdapter(_LifecycleFakeTransport transport) {
  return TdlibAdapter(
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
    detectCapabilities: () async =>
        const TdlibSchemaCapabilities(addProxyMode: TdlibAddProxyMode.flatArgs),
    initializeTdlib: (_) async {},
  );
}

typedef _OnSend =
    void Function(String constructor, _LifecycleFakeTransport transport);

class _LifecycleFakeTransport implements TdTransport {
  _LifecycleFakeTransport({
    required Map<String, List<TdObject>> responses,
    _OnSend? onSend,
  }) : _responses = responses,
       _onSend = onSend;

  final Map<String, List<TdObject>> _responses;
  final _OnSend? _onSend;
  final StreamController<TdObject> _updates =
      StreamController<TdObject>.broadcast();
  final List<String> requestConstructors = <String>[];

  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<TdObject> get updates => _updates.stream;

  @override
  Future<void> start() async {
    startCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
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
    _onSend?.call(constructor, this);
    final queue = _responses[constructor];
    if (queue == null || queue.isEmpty) {
      throw StateError('Missing fake response for $constructor');
    }
    return queue.removeAt(0);
  }

  void emitUpdate(TdObject update) {
    _updates.add(update);
  }
}
