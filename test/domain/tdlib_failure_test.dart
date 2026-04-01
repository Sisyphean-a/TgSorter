import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  group('TdlibFailure', () {
    test('keeps tdlib code and message for td errors', () {
      final failure = TdlibFailure.tdError(
        code: 420,
        message: 'FLOOD_WAIT_9',
        request: 'forwardMessages',
        phase: TdlibPhase.business,
      );

      expect(failure.kind, TdlibFailureKind.tdlib);
      expect(failure.code, 420);
      expect(failure.message, 'FLOOD_WAIT_9');
      expect(failure.request, 'forwardMessages');
      expect(failure.phase, TdlibPhase.business);
    });

    test('represents timeout with request context', () {
      final failure = TdlibFailure.timeout(
        request: 'getChat',
        phase: TdlibPhase.business,
        message: 'TDLib request timeout',
      );

      expect(failure.kind, TdlibFailureKind.timeout);
      expect(failure.code, isNull);
      expect(failure.request, 'getChat');
      expect(failure.message, 'TDLib request timeout');
    });
  });
}
