import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/telegram_media_group_layout.dart';

void main() {
  group('computeTelegramMediaGroupLayout', () {
    test('uses 2 and 3 item rows for five square items', () {
      final layout = computeTelegramMediaGroupLayout(
        aspectRatios: const [1, 1, 1, 1, 1],
        maxWidth: 300,
        minWidth: 72,
        spacing: 8,
      );

      expect(layout.rowCounts, const [2, 3]);
      expect(layout.items, hasLength(5));
    });

    test('uses 2 3 3 rows for eight square items', () {
      final layout = computeTelegramMediaGroupLayout(
        aspectRatios: const [1, 1, 1, 1, 1, 1, 1, 1],
        maxWidth: 300,
        minWidth: 72,
        spacing: 8,
      );

      expect(layout.rowCounts, const [2, 3, 3]);
    });

    test('uses 3 3 3 rows for nine square items', () {
      final layout = computeTelegramMediaGroupLayout(
        aspectRatios: const [1, 1, 1, 1, 1, 1, 1, 1, 1],
        maxWidth: 300,
        minWidth: 72,
        spacing: 8,
      );

      expect(layout.rowCounts, const [3, 3, 3]);
    });

    test('promotes wide first item into a leading single row', () {
      final layout = computeTelegramMediaGroupLayout(
        aspectRatios: const [2.5, 2.5, 1, 1, 1],
        maxWidth: 300,
        minWidth: 72,
        spacing: 8,
      );

      expect(layout.rowCounts.first, 1);
      expect(layout.rowCounts.length, 3);
    });
  });
}
