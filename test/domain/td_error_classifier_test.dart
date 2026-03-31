import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

void main() {
  group('classifyTdlibError', () {
    test('classifies flood wait as rateLimit', () {
      final error = TdlibRequestException(code: 420, message: 'FLOOD_WAIT_9');

      final kind = classifyTdlibError(error);

      expect(kind, TdErrorKind.rateLimit);
    });

    test('classifies auth error by code', () {
      final error = TdlibRequestException(code: 401, message: 'Unauthorized');

      final kind = classifyTdlibError(error);

      expect(kind, TdErrorKind.auth);
    });

    test('classifies network error by message', () {
      final error = TdlibRequestException(
        code: 500,
        message: 'NETWORK_CHANGED',
      );

      final kind = classifyTdlibError(error);

      expect(kind, TdErrorKind.network);
    });
  });
}
