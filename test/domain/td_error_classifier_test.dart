import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  group('classifyTdlibError', () {
    test('classifies flood wait as rateLimit', () {
      final error = TdlibFailure.tdError(
        code: 420,
        message: 'FLOOD_WAIT_9',
        request: 'forwardMessages',
        phase: TdlibPhase.business,
      );

      final kind = classifyTdlibError(error);

      expect(kind, TdErrorKind.rateLimit);
    });

    test('classifies auth error by code', () {
      final error = TdlibFailure.tdError(
        code: 401,
        message: 'Unauthorized',
        request: 'checkAuthenticationCode',
        phase: TdlibPhase.auth,
      );

      final kind = classifyTdlibError(error);

      expect(kind, TdErrorKind.auth);
    });

    test('classifies network error by message', () {
      final error = TdlibFailure.transport(
        message: 'NETWORK_CHANGED',
        request: 'getChats',
        phase: TdlibPhase.business,
      );

      final kind = classifyTdlibError(error);

      expect(kind, TdErrorKind.network);
    });
  });
}
