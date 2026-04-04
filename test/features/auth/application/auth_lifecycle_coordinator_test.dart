import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bootstrap starts gateway and clears current startup error', () async {
    final harness = await _buildHarness();
    harness.errors.report(title: '旧错误', message: '待清理');

    await harness.lifecycle.bootstrap();

    expect(harness.gateway.startCalls, 1);
    expect(harness.errors.currentError.value, isNull);
  });

  test('bootstrap maps tdlib failures to auth-scoped startup errors', () async {
    final harness = await _buildHarness();
    harness.gateway.startError = TdlibFailure.tdError(
      code: 401,
      message: 'PHONE_CODE_INVALID',
      request: 'start',
      phase: TdlibPhase.auth,
    );

    await harness.lifecycle.bootstrap();

    final event = harness.errors.structuredCurrentError.value;
    expect(event, isNotNull);
    expect(event!.scope, AppErrorScope.auth);
    expect(event.title, '启动失败');
    expect(event.message, '鉴权失败：PHONE_CODE_INVALID');
  });

  test('initialize binds auth stream and reports initialization errors', () async {
    final harness = await _buildHarness();
    final emittedStages = <AuthStage>[];

    harness.lifecycle.initialize(onStageChanged: emittedStages.add);
    harness.gateway.emitError(
      TdlibFailure.transport(
        message: 'NETWORK_UNREACHABLE',
        request: 'authState',
        phase: TdlibPhase.auth,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final event = harness.errors.structuredCurrentError.value;
    expect(event, isNotNull);
    expect(event!.title, '授权初始化失败');
    expect(event.message, '网络异常：NETWORK_UNREACHABLE');
    expect(emittedStages, isEmpty);
  });

  test('initialize maps auth states and navigates when ready', () async {
    final harness = await _buildHarness();
    final emittedStages = <AuthStage>[];

    harness.lifecycle.initialize(onStageChanged: emittedStages.add);
    harness.gateway.emitState(
      const TdAuthState(
        kind: TdAuthStateKind.waitPhoneNumber,
        rawType: 'authorizationStateWaitPhoneNumber',
      ),
    );
    harness.gateway.emitState(
      const TdAuthState(
        kind: TdAuthStateKind.ready,
        rawType: 'authorizationStateReady',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(emittedStages, [AuthStage.waitPhone, AuthStage.ready]);
    expect(harness.navigation.goToPipelineCalls, 1);
  });
}

Future<_Harness> _buildHarness() async {
  final gateway = _FakeAuthGateway();
  final errors = AppErrorController();
  final navigation = _FakeAuthNavigationPort();
  final lifecycle = AuthLifecycleCoordinator(
    auth: gateway,
    errors: errors,
    errorMapper: const AuthErrorMapper(),
    navigation: navigation,
  );
  return _Harness(
    gateway: gateway,
    errors: errors,
    navigation: navigation,
    lifecycle: lifecycle,
  );
}

class _Harness {
  const _Harness({
    required this.gateway,
    required this.errors,
    required this.navigation,
    required this.lifecycle,
  });

  final _FakeAuthGateway gateway;
  final AppErrorController errors;
  final _FakeAuthNavigationPort navigation;
  final AuthLifecycleCoordinator lifecycle;
}

class _FakeAuthGateway implements AuthGateway, SessionQueryGateway {
  final _authController = StreamController<TdAuthState>.broadcast();

  int startCalls = 0;
  Object? startError;

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  void emitState(TdAuthState state) {
    _authController.add(state);
  }

  void emitError(Object error) {
    _authController.addError(error);
  }

  @override
  Future<void> start() async {
    startCalls++;
    if (startError != null) {
      throw startError!;
    }
  }

  @override
  Future<void> restart() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];
}

class _FakeAuthNavigationPort implements AuthNavigationPort {
  int goToPipelineCalls = 0;

  @override
  void goToPipeline() {
    goToPipelineCalls++;
  }
}
