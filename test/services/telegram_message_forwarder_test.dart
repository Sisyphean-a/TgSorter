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
import 'package:tgsorter/app/services/telegram_message_forwarder.dart';

void main() {
  group('TelegramMessageForwarder', () {
    test('待发送目标消息确认后返回目标 ID', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'forwardMessages': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [
                _forwardedTextMessageJson(
                  88,
                  'copied',
                  sendingStateType: 'messageSendingStatePending',
                ),
              ],
            }),
          ],
          'getMessage': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(
              _forwardedTextMessageJson(
                88,
                'copied',
                sendingStateType: 'messageSendingStatePending',
              ),
            ),
            TdWireEnvelope.fromJson(_forwardedTextMessageJson(88, 'copied')),
          ],
        },
      );
      final forwarder = TelegramMessageForwarder(
        adapter: adapter,
        confirmTimeout: const Duration(milliseconds: 30),
        pollInterval: const Duration(milliseconds: 1),
      );

      final result = await forwarder.forwardMessagesAndConfirmDelivery(
        targetChatId: 999,
        sourceChatId: 777,
        sourceMessageIds: const [10],
        sendCopy: false,
        requestLabel: 'forwardMessages',
      );

      expect(result, <int>[88]);
      expect(adapter.getMessageCalls, greaterThan(0));
      expect(adapter.lastForwardSendCopy, isFalse);
    });

    test('确认超时后抛出异常', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'forwardMessages': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': [
                _forwardedTextMessageJson(
                  88,
                  'copied',
                  sendingStateType: 'messageSendingStatePending',
                ),
              ],
            }),
          ],
          'getMessage': List<TdWireEnvelope>.generate(
            12,
            (_) => TdWireEnvelope.fromJson(
              _forwardedTextMessageJson(
                88,
                'copied',
                sendingStateType: 'messageSendingStatePending',
              ),
            ),
          ),
        },
      );
      final forwarder = TelegramMessageForwarder(
        adapter: adapter,
        confirmTimeout: const Duration(milliseconds: 5),
        pollInterval: const Duration(milliseconds: 1),
      );

      await expectLater(
        () => forwarder.forwardMessagesAndConfirmDelivery(
          targetChatId: 999,
          sourceChatId: 777,
          sourceMessageIds: const [10],
          sendCopy: false,
          requestLabel: 'forwardMessages',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('发送状态确认超时'),
          ),
        ),
      );
    });

    test('转发结果为空时抛出异常', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: <String, List<TdWireEnvelope>>{
          'forwardMessages': <TdWireEnvelope>[
            TdWireEnvelope.fromJson(<String, dynamic>{
              '@type': 'messages',
              'messages': const [],
            }),
          ],
        },
      );
      final forwarder = TelegramMessageForwarder(adapter: adapter);

      await expectLater(
        () => forwarder.forwardMessagesAndConfirmDelivery(
          targetChatId: 999,
          sourceChatId: 777,
          sourceMessageIds: const [10],
          sendCopy: false,
          requestLabel: 'forwardMessages',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            contains('无法提取目标消息 ID'),
          ),
        ),
      );
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
  int getMessageCalls = 0;
  bool? lastForwardSendCopy;

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (function is GetMessage) {
      getMessageCalls++;
    }
    if (function is ForwardMessages) {
      lastForwardSendCopy = function.sendCopy;
    }

    final constructor = function.getConstructor();
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
    throw UnimplementedError();
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

Map<String, dynamic> _textMessageJson(int id, String text) {
  return <String, dynamic>{
    'id': id,
    'content': {
      '@type': 'messageText',
      'text': {'text': text, 'entities': []},
    },
  };
}

Map<String, dynamic> _forwardedTextMessageJson(
  int id,
  String text, {
  String? sendingStateType,
}) {
  final message = Map<String, dynamic>.from(_textMessageJson(id, text));
  if (sendingStateType == null) {
    return message;
  }
  message['sending_state'] = <String, dynamic>{'@type': sendingStateType};
  return message;
}
