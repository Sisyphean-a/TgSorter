import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';

void main() {
  test('maps auth states to stages without navigation before ready', () {
    final navigation = _FakeAuthNavigationPort();
    final coordinator = AuthLifecycleCoordinator(navigation);

    final waitPhoneStage = coordinator.handle(
      const TdAuthState(
        kind: TdAuthStateKind.waitPhoneNumber,
        rawType: 'authorizationStateWaitPhoneNumber',
      ),
    );
    final waitCodeStage = coordinator.handle(
      const TdAuthState(
        kind: TdAuthStateKind.waitCode,
        rawType: 'authorizationStateWaitCode',
      ),
    );
    final loadingStage = coordinator.handle(
      const TdAuthState(
        kind: TdAuthStateKind.waitTdlibParameters,
        rawType: 'authorizationStateWaitTdlibParameters',
      ),
    );

    expect(waitPhoneStage, AuthStage.waitPhone);
    expect(waitCodeStage, AuthStage.waitCode);
    expect(loadingStage, AuthStage.loading);
    expect(navigation.goToPipelineCalls, 0);
  });

  test('navigates to pipeline when auth becomes ready', () {
    final navigation = _FakeAuthNavigationPort();
    final coordinator = AuthLifecycleCoordinator(navigation);

    final stage = coordinator.handle(
      const TdAuthState(
        kind: TdAuthStateKind.ready,
        rawType: 'authorizationStateReady',
      ),
    );

    expect(stage, AuthStage.ready);
    expect(navigation.goToPipelineCalls, 1);
  });
}

class _FakeAuthNavigationPort implements AuthNavigationPort {
  int goToPipelineCalls = 0;

  @override
  void goToPipeline() {
    goToPipelineCalls++;
  }
}
