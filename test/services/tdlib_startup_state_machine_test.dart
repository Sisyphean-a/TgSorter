import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';

void main() {
  group('TdlibAdapter startup state machine', () {
    test(
      'runs init to auth when authorization waits for tdlib params',
      () async {
        final transport = _FakeTransport(
          responses: <String, List<TdObject>>{
            'getAuthorizationState': <TdObject>[
              const AuthorizationStateWaitTdlibParameters(),
            ],
            'setTdlibParameters': <TdObject>[const Ok()],
            'disableProxy': <TdObject>[const Ok()],
          },
        );
        final adapter = TdlibAdapter(
          transport: transport,
          credentials: const TdlibCredentials(apiId: 1, apiHash: 'hash'),
          runtimePaths: const TdlibRuntimePaths(
            libraryPath: 'tdjson.dll',
            databaseDirectory: 'db',
            filesDirectory: 'files',
          ),
          initializeTdlib: (_) async {},
        );
        final states = <TdlibStartupState>[];
        final sub = adapter.startupStates.listen(states.add);

        await adapter.start();

        expect(states, <TdlibStartupState>[
          TdlibStartupState.init,
          TdlibStartupState.setParams,
          TdlibStartupState.auth,
        ]);
        expect(transport.requestConstructors, <String>[
          'getAuthorizationState',
          'setTdlibParameters',
          'disableProxy',
        ]);
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
        credentials: const TdlibCredentials(apiId: 1, apiHash: 'hash'),
        runtimePaths: const TdlibRuntimePaths(
          libraryPath: 'tdjson.dll',
          databaseDirectory: 'db',
          filesDirectory: 'files',
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
