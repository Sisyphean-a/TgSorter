import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_json_logger.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';

void main() {
  group('TdClientTransport', () {
    test(
      'does not decode raw updates until typed update stream is listened to',
      () async {
        final logs = <String>[];
        final rawTransport = _FakeRawTransport();
        final transport = TdClientTransport(
          rawTransport: rawTransport,
          logger: TdJsonLogger(
            isEnabled: true,
            sink:
                ({
                  required String message,
                  required String name,
                  Object? error,
                  StackTrace? stackTrace,
                }) {
                  logs.add(message);
                },
          ),
        );

        await transport.start();
        rawTransport.emitUpdate(<String, dynamic>{
          '@type': 'addedProxy',
          'proxy': <String, dynamic>{'@type': 'proxy', 'id': 1},
        });
        await Future<void>.delayed(Duration.zero);
        await transport.stop();

        expect(
          logs.where((entry) => entry.contains('[TD PARSE ERROR]')),
          isEmpty,
        );
      },
    );

    test(
      'forwards known typed updates when compatibility stream is used',
      () async {
        final rawTransport = _FakeRawTransport();
        final transport = TdClientTransport(
          rawTransport: rawTransport,
          logger: TdJsonLogger(isEnabled: false),
        );

        await transport.start();
        final updateFuture = transport.updates.first;
        rawTransport.emitUpdate(<String, dynamic>{
          '@type': 'updateConnectionState',
          'state': <String, dynamic>{'@type': 'connectionStateReady'},
        });

        final update = await updateFuture.timeout(const Duration(seconds: 1));
        await transport.stop();

        expect(update, isA<UpdateConnectionState>());
        expect(
          (update as UpdateConnectionState).state,
          isA<ConnectionStateReady>(),
        );
      },
    );

    test('ignores unknown raw-only updates on compatibility stream', () async {
      final logs = <String>[];
      final rawTransport = _FakeRawTransport();
      final transport = TdClientTransport(
        rawTransport: rawTransport,
        logger: TdJsonLogger(
          isEnabled: true,
          sink:
              ({
                required String message,
                required String name,
                Object? error,
                StackTrace? stackTrace,
              }) {
                logs.add(message);
              },
        ),
      );

      await transport.start();
      final updates = <TdObject>[];
      final errors = <Object>[];
      final subscription = transport.updates.listen(
        updates.add,
        onError: errors.add,
      );
      rawTransport.emitUpdate(<String, dynamic>{
        '@type': 'addedProxy',
        'proxy': <String, dynamic>{'@type': 'proxy', 'id': 1},
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await subscription.cancel();
      await transport.stop();

      expect(updates, isEmpty);
      expect(errors, isEmpty);
      expect(
        logs.where((entry) => entry.contains('[TD PARSE ERROR]')),
        isEmpty,
      );
    });
  });
}

class _FakeRawTransport extends TdRawTransport {
  _FakeRawTransport()
    : _updatesController = StreamController<Map<String, dynamic>>.broadcast(),
      super(logger: TdJsonLogger(isEnabled: false));

  final StreamController<Map<String, dynamic>> _updatesController;
  bool started = false;

  @override
  Stream<Map<String, dynamic>> get updates => _updatesController.stream;

  @override
  Future<void> start() async {
    started = true;
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
    throw UnimplementedError();
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
