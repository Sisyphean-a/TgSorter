import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';
import 'package:tgsorter/app/services/telegram_login_alert_parser.dart';

void main() {
  group('TelegramLoginAlertParser', () {
    test('parses login code from updateNewMessage', () {
      final alert = TelegramLoginAlertParser.parse(<String, dynamic>{
        '@type': 'updateNewMessage',
        'message': <String, dynamic>{
          '@type': 'message',
          'id': 18,
          'chat_id': 777000,
          'date': 1700000000,
          'sender_id': <String, dynamic>{
            '@type': 'messageSenderUser',
            'user_id': 777000,
          },
          'content': <String, dynamic>{
            '@type': 'messageText',
            'text': <String, dynamic>{
              'text': 'Login code: 404237\nDo not share it with anyone.',
              'entities': <Object>[],
            },
          },
        },
      }, nowMs: 1700000000 * 1000 + 60000);

      expect(alert, isNotNull);
      expect(alert!.kind, TelegramLoginAlertKind.code);
      expect(alert.code, '404237');
      expect(alert.messageId, 18);
      expect(alert.sourceLabel, 'Telegram 官方账号 777000');
      expect(alert.status, TelegramLoginAlertStatus.active);
    });

    test('parses new login reminder from updateChatLastMessage', () {
      final alert = TelegramLoginAlertParser.parse(<String, dynamic>{
        '@type': 'updateChatLastMessage',
        'chat_id': 777000,
        'last_message': <String, dynamic>{
          '@type': 'message',
          'id': 27,
          'chat_id': 777000,
          'date': 1700000030,
          'sender_id': <String, dynamic>{
            '@type': 'messageSenderUser',
            'user_id': 777000,
          },
          'content': <String, dynamic>{
            '@type': 'messageText',
            'text': <String, dynamic>{
              'text':
                  'New login.\nDevice: Telegram iOS 11.7\nLocation: Shanghai, China',
              'entities': <Object>[],
            },
          },
        },
      }, nowMs: 1700000030 * 1000);

      expect(alert, isNotNull);
      expect(alert!.kind, TelegramLoginAlertKind.newLogin);
      expect(alert.deviceSummary, 'Telegram iOS 11.7');
      expect(alert.location, 'Shanghai, China');
      expect(alert.status, TelegramLoginAlertStatus.info);
    });

    test('ignores non-official or non-text messages', () {
      final alert = TelegramLoginAlertParser.parse(<String, dynamic>{
        '@type': 'updateNewMessage',
        'message': <String, dynamic>{
          '@type': 'message',
          'id': 9,
          'chat_id': 42,
          'date': 1700000000,
          'sender_id': <String, dynamic>{
            '@type': 'messageSenderUser',
            'user_id': 42,
          },
          'content': <String, dynamic>{'@type': 'messagePhoto'},
        },
      }, nowMs: 1700000000 * 1000);

      expect(alert, isNull);
    });
  });
}
