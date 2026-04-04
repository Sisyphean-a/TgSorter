import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';

void main() {
  group('clampVideoSeekTarget', () {
    test('clamps negative target to zero', () {
      final result = clampVideoSeekTarget(
        target: const Duration(seconds: -5),
        duration: const Duration(minutes: 2),
      );

      expect(result, Duration.zero);
    });

    test('clamps overflow target to duration', () {
      final result = clampVideoSeekTarget(
        target: const Duration(minutes: 3),
        duration: const Duration(minutes: 2),
      );

      expect(result, const Duration(minutes: 2));
    });

    test('keeps in-range target unchanged', () {
      final result = clampVideoSeekTarget(
        target: const Duration(seconds: 35),
        duration: const Duration(minutes: 2),
      );

      expect(result, const Duration(seconds: 35));
    });
  });
}
