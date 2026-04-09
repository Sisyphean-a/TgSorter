import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

void main() {
  group('TdResponseReader', () {
    test('parses int values from tdlib numeric strings', () {
      expect(
        TdResponseReader.readInt(<String, dynamic>{
          'value': '1774463496',
        }, 'value'),
        1774463496,
      );
    });

    test('throws clear error when required field is missing', () {
      expect(
        () => TdResponseReader.readString(<String, dynamic>{
          '@type': 'chat',
        }, 'title'),
        throwsA(
          isA<TdResponseReadError>().having(
            (error) => error.toString(),
            'message',
            contains('title'),
          ),
        ),
      );
    });

    test('maps td error response to wire error', () {
      final envelope = TdWireEnvelope.fromJson(<String, dynamic>{
        '@type': 'error',
        '@extra': '1',
        'code': 401,
        'message': 'PHONE_NUMBER_INVALID',
      });

      expect(envelope.isError, isTrue);
      expect(envelope.errorCode, 401);
      expect(envelope.errorMessage, 'PHONE_NUMBER_INVALID');
      expect(envelope.extra, '1');
    });
  });
}
