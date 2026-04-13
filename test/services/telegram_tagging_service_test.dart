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
import 'package:tgsorter/app/services/telegram_tagging_service.dart';

void main() {
  group('TelegramTaggingService', () {
    test('text message sends EditMessageText', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: {
          'getMessage': [TdWireEnvelope.fromJson(_textMessageJson(1, 'hello'))],
          'editMessageText': [
            TdWireEnvelope.fromJson(_textMessageJson(1, 'hello #摄影')),
          ],
        },
      );
      final service = TelegramTaggingService(adapter: adapter);

      final result = await service.applyTag(
        sourceChatId: 777,
        messageIds: const [1],
        tagName: '摄影',
      );

      expect(result.changed, isTrue);
      expect(adapter.editTextPayloads, ['hello #摄影']);
      expect(result.message.preview.text?.text, 'hello #摄影');
    });

    test('media message sends EditMessageCaption', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: {
          'getMessage': [
            TdWireEnvelope.fromJson(_photoMessageJson(2, 'caption')),
          ],
          'editMessageCaption': [
            TdWireEnvelope.fromJson(_photoMessageJson(2, 'caption #摄影')),
          ],
        },
      );
      final service = TelegramTaggingService(adapter: adapter);

      final result = await service.applyTag(
        sourceChatId: 777,
        messageIds: const [2],
        tagName: '摄影',
      );

      expect(result.changed, isTrue);
      expect(adapter.editCaptionPayloads, ['caption #摄影']);
      expect(result.message.preview.text?.text, 'caption #摄影');
    });

    test('existing tag returns unchanged without edit request', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: {
          'getMessage': [
            TdWireEnvelope.fromJson(_textMessageJson(3, 'hello #摄影')),
          ],
        },
      );
      final service = TelegramTaggingService(adapter: adapter);

      final result = await service.applyTag(
        sourceChatId: 777,
        messageIds: const [3],
        tagName: '摄影',
      );

      expect(result.changed, isFalse);
      expect(adapter.editTextPayloads, isEmpty);
      expect(adapter.editCaptionPayloads, isEmpty);
    });

    test('no editable message throws', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: {
          'getMessage': [
            TdWireEnvelope.fromJson(
              _textMessageJson(4, 'locked', canBeEdited: false),
            ),
          ],
        },
      );
      final service = TelegramTaggingService(adapter: adapter);

      await expectLater(
        service.applyTag(
          sourceChatId: 777,
          messageIds: const [4],
          tagName: '摄影',
        ),
        throwsStateError,
      );
    });

    test('edit failure propagates', () async {
      final adapter = _FakeTdlibAdapter(
        wireResponses: {
          'getMessage': [TdWireEnvelope.fromJson(_textMessageJson(5, 'hello'))],
          'editMessageText': [StateError('edit failed')],
        },
      );
      final service = TelegramTaggingService(adapter: adapter);

      await expectLater(
        service.applyTag(
          sourceChatId: 777,
          messageIds: const [5],
          tagName: '摄影',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'outgoing message without can_be_edited flag still attempts text edit',
      () async {
        final adapter = _FakeTdlibAdapter(
          wireResponses: {
            'getMessage': [
              TdWireEnvelope.fromJson(
                _textMessageJson(
                  6,
                  'hello',
                  includeCanBeEdited: false,
                  isOutgoing: true,
                ),
              ),
            ],
            'editMessageText': [
              TdWireEnvelope.fromJson(_textMessageJson(6, 'hello #摄影')),
            ],
          },
        );
        final service = TelegramTaggingService(adapter: adapter);

        final result = await service.applyTag(
          sourceChatId: 777,
          messageIds: const [6],
          tagName: '摄影',
        );

        expect(result.changed, isTrue);
        expect(adapter.editTextPayloads, ['hello #摄影']);
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

  final Map<String, List<Object>> wireResponses;
  final List<String> editTextPayloads = [];
  final List<String> editCaptionPayloads = [];

  @override
  Future<TdWireEnvelope> sendWire(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (function is EditMessageText) {
      final content = function.inputMessageContent as InputMessageText;
      editTextPayloads.add(content.text.text);
    }
    if (function is EditMessageCaption) {
      editCaptionPayloads.add(function.caption?.text ?? '');
    }
    final queue = wireResponses[function.getConstructor()];
    if (queue == null || queue.isEmpty) {
      throw StateError(
        'Missing fake wire response for ${function.getConstructor()}',
      );
    }
    final next = queue.removeAt(0);
    if (next is TdWireEnvelope) {
      return next;
    }
    if (next is Error) {
      throw next;
    }
    throw StateError('Unsupported fake response type: ${next.runtimeType}');
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
  Future<TdObject> sendWithTimeout(TdFunction function, Duration timeout) {
    throw UnimplementedError();
  }
}

Map<String, dynamic> _textMessageJson(
  int id,
  String text, {
  bool canBeEdited = true,
  bool includeCanBeEdited = true,
  bool isOutgoing = false,
}) {
  final payload = {
    'id': id,
    'is_outgoing': isOutgoing,
    'content': {
      '@type': 'messageText',
      'text': {'text': text, 'entities': []},
    },
  };
  if (includeCanBeEdited) {
    payload['can_be_edited'] = canBeEdited;
  }
  return payload;
}

Map<String, dynamic> _photoMessageJson(int id, String caption) {
  return {
    'id': id,
    'can_be_edited': true,
    'content': {
      '@type': 'messagePhoto',
      'caption': {'text': caption, 'entities': []},
      'photo': {
        'sizes': [
          {
            'type': 's',
            'width': 90,
            'height': 90,
            'photo': {
              'id': id + 100,
              'local': {'path': ''},
            },
          },
        ],
      },
    },
  };
}
