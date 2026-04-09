import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_update_parser.dart';

void main() {
  group('TdUpdateParser', () {
    test('parses updateMessageSendSucceeded', () {
      final parsed = TdUpdateParser.parse(<String, dynamic>{
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

      final result = parsed.messageSendResult;
      expect(result, isNotNull);
      expect(result!.chatId, 999);
      expect(result.oldMessageId, 77);
      expect(result.messageId, 88);
      expect(result.isSuccess, isTrue);
    });

    test('parses updateMessageSendFailed', () {
      final parsed = TdUpdateParser.parse(<String, dynamic>{
        '@type': 'updateMessageSendFailed',
        'old_message_id': 77,
        'message': <String, dynamic>{
          '@type': 'message',
          'id': 91,
          'chat_id': 999,
          'content': <String, dynamic>{
            '@type': 'messageText',
            'text': <String, dynamic>{'text': 'failed', 'entities': <Object>[]},
          },
        },
        'error_code': 406,
        'error_message': 'SEND_FAILED',
      });

      final result = parsed.messageSendResult;
      expect(result, isNotNull);
      expect(result!.chatId, 999);
      expect(result.oldMessageId, 77);
      expect(result.messageId, 91);
      expect(result.isSuccess, isFalse);
      expect(result.errorCode, 406);
      expect(result.errorMessage, 'SEND_FAILED');
    });
  });
}
