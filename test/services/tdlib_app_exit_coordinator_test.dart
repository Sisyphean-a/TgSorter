import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/tdlib_app_exit_coordinator.dart';

void main() {
  group('TdlibAppExitCoordinator', () {
    test('requestExit waits for tdlib close before allowing exit', () async {
      final closeStarted = Completer<void>();
      final releaseClose = Completer<void>();
      final coordinator = TdlibAppExitCoordinator(
        close: () async {
          closeStarted.complete();
          await releaseClose.future;
        },
      );

      var completed = false;
      final exitFuture = coordinator.requestExit();
      exitFuture.then((_) {
        completed = true;
      });
      await closeStarted.future;
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      releaseClose.complete();

      await expectLater(exitFuture, completion(AppExitResponse.exit));
    });

    test('concurrent exit requests share the same close operation', () async {
      var closeCalls = 0;
      final releaseClose = Completer<void>();
      final coordinator = TdlibAppExitCoordinator(
        close: () async {
          closeCalls++;
          await releaseClose.future;
        },
      );

      final first = coordinator.requestExit();
      final second = coordinator.requestExit();
      releaseClose.complete();

      await expectLater(first, completion(AppExitResponse.exit));
      await expectLater(second, completion(AppExitResponse.exit));
      expect(closeCalls, 1);
    });

    test('requestExit cancels exit when tdlib close fails', () async {
      final coordinator = TdlibAppExitCoordinator(
        close: () async {
          throw StateError('close failed');
        },
      );

      await expectLater(
        coordinator.requestExit(),
        completion(AppExitResponse.cancel),
      );
    });
  });
}
