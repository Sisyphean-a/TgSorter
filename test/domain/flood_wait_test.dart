import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';

void main() {
  group('parseFloodWaitSeconds', () {
    test('can parse FLOOD_WAIT_15', () {
      expect(parseFloodWaitSeconds('Too Many Requests: FLOOD_WAIT_15'), 15);
    });

    test('can parse human readable wait format', () {
      expect(parseFloodWaitSeconds('A wait of 42 seconds is required'), 42);
    });

    test('returns null when no wait number exists', () {
      expect(parseFloodWaitSeconds('network unstable'), isNull);
    });
  });
}
