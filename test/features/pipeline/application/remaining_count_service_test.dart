import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';

void main() {
  test('remaining count ignores stale response', () async {
    final service = RemainingCountService();

    final first = service.beginRequest();
    final second = service.beginRequest();

    expect(service.shouldApply(first), isFalse);
    expect(service.shouldApply(second), isTrue);
  });
}
