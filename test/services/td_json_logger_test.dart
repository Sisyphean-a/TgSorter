import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_json_logger.dart';

void main() {
  group('parseTdJsonLogDetailLevel', () {
    test('maps debug aliases to verbose and falls back to summary', () {
      expect(
        parseTdJsonLogDetailLevel('verbose'),
        TdJsonLogDetailLevel.verbose,
      );
      expect(parseTdJsonLogDetailLevel('DEBUG'), TdJsonLogDetailLevel.verbose);
      expect(parseTdJsonLogDetailLevel(''), TdJsonLogDetailLevel.summary);
      expect(parseTdJsonLogDetailLevel('noise'), TdJsonLogDetailLevel.summary);
    });
  });

  group('TdJsonLogger', () {
    test('summary mode omits full request payload', () {
      final records = <_LogRecord>[];
      final logger = TdJsonLogger(
        isEnabled: true,
        sink:
            ({
              required String message,
              required String name,
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(
                _LogRecord(
                  message: message,
                  name: name,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
      );

      logger.logSend(
        request: 'getChatHistory',
        extra: '1711962000123456',
        payload: <String, dynamic>{
          '@type': 'getChatHistory',
          '@extra': '1711962000123456',
          'chat_id': 42,
        },
      );

      expect(records, hasLength(1));
      expect(records.single.name, 'TdJsonLogger');
      expect(records.single.message, contains('[TD SEND]'));
      expect(records.single.message, contains('request=getChatHistory'));
      expect(records.single.message, contains('extra=1711962000123456'));
      expect(records.single.message, contains('chat_id=42'));
      expect(records.single.message, isNot(contains('payload=')));
    });

    test('verbose mode keeps full request payload', () {
      final records = <_LogRecord>[];
      final logger = TdJsonLogger(
        isEnabled: true,
        detailLevel: TdJsonLogDetailLevel.verbose,
        sink:
            ({
              required String message,
              required String name,
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(
                _LogRecord(
                  message: message,
                  name: name,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
      );

      logger.logSend(
        request: 'getChatHistory',
        extra: '1711962000123456',
        payload: <String, dynamic>{
          '@type': 'getChatHistory',
          '@extra': '1711962000123456',
          'chat_id': 42,
        },
      );

      expect(records, hasLength(1));
      expect(records.single.message, contains('payload='));
      expect(records.single.message, contains('"@type":"getChatHistory"'));
    });

    test('logs parse failure with raw payload and reason', () {
      final records = <_LogRecord>[];
      final logger = TdJsonLogger(
        isEnabled: true,
        sink:
            ({
              required String message,
              required String name,
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(
                _LogRecord(
                  message: message,
                  name: name,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
      );

      logger.logParseError(
        stage: 'raw_decode',
        payload: '{"@type":"ok"',
        reason: 'FormatException: Unexpected end of input',
        context: 'request=getMe',
      );

      expect(records, hasLength(1));
      expect(records.single.message, contains('[TD PARSE ERROR]'));
      expect(records.single.message, contains('stage=raw_decode'));
      expect(records.single.message, contains('context=request=getMe'));
      expect(
        records.single.message,
        contains('reason=FormatException: Unexpected end of input'),
      );
      expect(records.single.message, contains('payload={"@type":"ok"'));
    });

    test('suppresses noisy updateOption logs by default', () {
      final records = <_LogRecord>[];
      final logger = TdJsonLogger(
        isEnabled: true,
        sink:
            ({
              required String message,
              required String name,
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(
                _LogRecord(
                  message: message,
                  name: name,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
      );

      logger.logUpdate(
        type: 'updateOption',
        payload: <String, dynamic>{
          '@type': 'updateOption',
          'name': 'bio_length_max',
        },
      );

      expect(records, isEmpty);
    });

    test('keeps structural updates visible', () {
      final records = <_LogRecord>[];
      final logger = TdJsonLogger(
        isEnabled: true,
        sink:
            ({
              required String message,
              required String name,
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(
                _LogRecord(
                  message: message,
                  name: name,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
      );

      logger.logUpdate(
        type: 'updateNewChat',
        payload: <String, dynamic>{'@type': 'updateNewChat'},
      );

      expect(records, hasLength(1));
      expect(records.single.message, contains('type=updateNewChat'));
    });

    test('deduplicates updateChatLastMessage after updateNewMessage', () {
      final records = <_LogRecord>[];
      final logger = TdJsonLogger(
        isEnabled: true,
        sink:
            ({
              required String message,
              required String name,
              Object? error,
              StackTrace? stackTrace,
            }) {
              records.add(
                _LogRecord(
                  message: message,
                  name: name,
                  error: error,
                  stackTrace: stackTrace,
                ),
              );
            },
      );

      logger.logUpdate(
        type: 'updateNewMessage',
        payload: <String, dynamic>{
          '@type': 'updateNewMessage',
          'message': <String, dynamic>{
            'id': 9001,
            'chat_id': 42,
            'content': <String, dynamic>{'@type': 'messageText'},
          },
        },
      );
      logger.logUpdate(
        type: 'updateChatLastMessage',
        payload: <String, dynamic>{
          '@type': 'updateChatLastMessage',
          'chat_id': 42,
          'last_message': <String, dynamic>{
            'id': 9001,
            'content': <String, dynamic>{'@type': 'messageText'},
          },
        },
      );

      expect(records, hasLength(1));
      expect(records.single.message, contains('type=updateNewMessage'));
      expect(records.single.message, contains('message_id=9001'));
    });
  });
}

class _LogRecord {
  const _LogRecord({
    required this.message,
    required this.name,
    this.error,
    this.stackTrace,
  });

  final String message;
  final String name;
  final Object? error;
  final StackTrace? stackTrace;
}
