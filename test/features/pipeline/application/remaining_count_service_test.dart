import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/pipeline/application/remaining_count_service.dart';

void main() {
  test('remaining count ignores stale response', () async {
    final service = RemainingCountService();
    final first = Completer<int>();
    final second = Completer<int>();
    final appliedValues = <int>[];
    final loadingStates = <bool>[];

    final firstFuture = service.refreshRemainingCount(
      loadCount: () => first.future,
      onStart: () => loadingStates.add(true),
      onSuccess: appliedValues.add,
      onError: (_) {},
      onComplete: () => loadingStates.add(false),
    );
    final secondFuture = service.refreshRemainingCount(
      loadCount: () => second.future,
      onStart: () => loadingStates.add(true),
      onSuccess: appliedValues.add,
      onError: (_) {},
      onComplete: () => loadingStates.add(false),
    );

    first.complete(41);
    second.complete(42);
    await Future.wait(<Future<void>>[firstFuture, secondFuture]);

    expect(appliedValues, <int>[42]);
    expect(loadingStates, <bool>[true, true, false]);
  });
}
