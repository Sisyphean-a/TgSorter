import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';
import 'package:tgsorter/app/services/td_json_logger.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';

void main() {
  group('TdRawTransport', () {
    test(
      'resolves TdPlugin at start time instead of constructor time',
      () async {
        final original = TdPlugin.instance;
        final first = _FakeTdPlugin();
        final second = _FakeTdPlugin();
        TdPlugin.instance = first;
        final transport = TdRawTransport(
          logger: TdJsonLogger(isEnabled: false),
          pollInterval: const Duration(milliseconds: 1),
        );

        TdPlugin.instance = second;
        await transport.start();
        await transport.stop();

        expect(first.createCallCount, 0);
        expect(second.createCallCount, 1);
        TdPlugin.instance = original;
      },
    );

    test('logs full request payload with constructor and extra', () async {
      final logs = <String>[];
      final plugin = _FakeTdPlugin();
      final transport = TdRawTransport(
        plugin: plugin,
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
        pollInterval: const Duration(milliseconds: 1),
      );

      await transport.start();
      final response = transport.send(
        const GetMe(),
        timeout: const Duration(milliseconds: 50),
      );
      final extra = plugin.lastSentPayload!['@extra'] as String;
      plugin.enqueueReceive('{"@type":"ok","@extra":"$extra","@client_id":1}');

      await response;
      await transport.stop();

      expect(logs.any((entry) => entry.contains('[TD SEND]')), isTrue);
      expect(
        logs.singleWhere((entry) => entry.contains('[TD SEND]')),
        contains('request=getMe'),
      );
      expect(
        logs.singleWhere((entry) => entry.contains('[TD SEND]')),
        contains('"@type":"getMe"'),
      );
      expect(
        logs.singleWhere((entry) => entry.contains('[TD SEND]')),
        contains('"@extra":"$extra"'),
      );
    });

    test('logs full receive payload before parsing', () async {
      final logs = <String>[];
      final plugin = _FakeTdPlugin();
      final transport = TdRawTransport(
        plugin: plugin,
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
        pollInterval: const Duration(milliseconds: 1),
      );

      await transport.start();
      final response = transport.send(
        const GetMe(),
        timeout: const Duration(milliseconds: 50),
      );
      final extra = plugin.lastSentPayload!['@extra'] as String;
      plugin.enqueueReceive('{"@type":"ok","@extra":"$extra","@client_id":1}');

      final payload = await response;
      await transport.stop();

      expect(payload['@type'], 'ok');
      expect(logs.any((entry) => entry.contains('[TD RECV]')), isTrue);
      expect(
        logs.singleWhere((entry) => entry.contains('[TD RECV]')),
        contains('type=ok'),
      );
      expect(
        logs.singleWhere((entry) => entry.contains('[TD RECV]')),
        contains('extra=$extra'),
      );
      expect(
        logs.singleWhere((entry) => entry.contains('[TD RECV]')),
        contains('"@type":"ok"'),
      );
    });

    test('logs parse failure with raw payload and reason', () async {
      final logs = <String>[];
      final plugin = _FakeTdPlugin()..enqueueReceive('{"@type":"ok"');
      final transport = TdRawTransport(
        plugin: plugin,
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
        pollInterval: const Duration(milliseconds: 1),
      );

      await transport.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await transport.stop();

      expect(logs.any((entry) => entry.contains('[TD PARSE ERROR]')), isTrue);
      expect(
        logs.singleWhere((entry) => entry.contains('[TD PARSE ERROR]')),
        contains('stage=raw_receive'),
      );
      expect(
        logs.singleWhere((entry) => entry.contains('[TD PARSE ERROR]')),
        contains('payload={"@type":"ok"'),
      );
    });

    test('uses unique extras even when clock value repeats', () async {
      final plugin = _FakeTdPlugin();
      final transport = TdRawTransport(
        plugin: plugin,
        logger: TdJsonLogger(isEnabled: false),
        pollInterval: const Duration(milliseconds: 1),
        nowMicros: () => 42,
      );

      await transport.start();
      final first = transport.send(
        const GetMe(),
        timeout: const Duration(milliseconds: 50),
      );
      final second = transport.send(
        const GetAuthorizationState(),
        timeout: const Duration(milliseconds: 50),
      );
      final requestPayloads = plugin.sentPayloads
          .where((payload) => payload['@extra'] != null)
          .toList(growable: false);
      final firstExtra = requestPayloads[0]['@extra'] as String;
      final secondExtra = requestPayloads[1]['@extra'] as String;

      plugin.enqueueReceive(
        '{"@type":"ok","@extra":"$firstExtra","@client_id":1}',
      );
      plugin.enqueueReceive(
        '{"@type":"ok","@extra":"$secondExtra","@client_id":1}',
      );

      final firstPayload = await first;
      final secondPayload = await second;
      await transport.stop();

      expect(firstExtra, isNot(equals(secondExtra)));
      expect(firstPayload['@extra'], firstExtra);
      expect(secondPayload['@extra'], secondExtra);
    });
  });
}

class _FakeTdPlugin extends TdPlugin {
  final Queue<String> _receiveQueue = Queue<String>();

  final List<Map<String, dynamic>> sentPayloads = <Map<String, dynamic>>[];
  Map<String, dynamic>? lastSentPayload;
  int _nextClientId = 1;
  int createCallCount = 0;

  @override
  int tdCreate() {
    createCallCount++;
    return _nextClientId++;
  }

  @override
  String? tdReceive([double timeout = 8]) {
    if (_receiveQueue.isEmpty) {
      return null;
    }
    return _receiveQueue.removeFirst();
  }

  @override
  void tdSend(int clientId, String event) {
    lastSentPayload = Map<String, dynamic>.from(
      (jsonDecode(event) as Map).cast<String, dynamic>(),
    );
    sentPayloads.add(lastSentPayload!);
  }

  void enqueueReceive(String event) {
    _receiveQueue.add(event);
  }

  @override
  num tdGetTimeout() => 0;

  @override
  String? tdExecute(String event) => null;

  @override
  int tdJsonClientCreate() => 0;

  @override
  void tdJsonClientDestroy(int clientId) {}

  @override
  String? tdJsonClientExecute(String event) => null;

  @override
  String? tdJsonClientReceive(int clientId, [double timeout = 8]) => null;

  @override
  void tdJsonClientSend(int clientId, String event) {}

  @override
  void setLogMessageCallback(int maxVerbosityLevel, callback) {}

  @override
  void removeLogMessageCallback() {}
}
