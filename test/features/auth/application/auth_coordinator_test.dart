import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('onInit waits until first frame before initializing lifecycle', (
    tester,
  ) async {
    final harness = await _buildHarness();

    harness.coordinator.onInit();

    expect(harness.lifecycle.initializeCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(harness.lifecycle.initializeCalls, 1);
  });

  test(
    'retryStartup restores previous auth stage when restart fails',
    () async {
      final harness = await _buildHarness();
      harness.coordinator.stage.value = AuthStage.waitCode;
      harness.gateway.restartError = StateError('restart failed');

      await harness.coordinator.retryStartup();

      expect(harness.coordinator.loading.value, isFalse);
      expect(harness.coordinator.stage.value, AuthStage.waitCode);
    },
  );

  test(
    'submitPhone ignores a second request while first submit is still running',
    () async {
      final harness = await _buildHarness();
      harness.gateway.submitPhoneCompleter = Completer<void>();

      final firstSubmit = harness.coordinator.submitPhone('+8613800000000');
      final secondSubmit = harness.coordinator.submitPhone('+8613900000000');

      await Future<void>.delayed(Duration.zero);

      expect(harness.gateway.submitPhoneCalls, 1);

      harness.gateway.submitPhoneCompleter!.complete();
      await firstSubmit;
      await secondSubmit;
    },
  );
}

Future<_CoordinatorHarness> _buildHarness() async {
  final gateway = _FakeAuthGateway();
  final errors = AppErrorController();
  final lifecycle = _SpyAuthLifecycleCoordinator(
    auth: gateway,
    errors: errors,
    errorMapper: const AuthErrorMapper(),
    navigation: _FakeAuthNavigationPort(),
  );
  final coordinator = AuthCoordinator(gateway, errors, lifecycle: lifecycle);
  return _CoordinatorHarness(
    coordinator: coordinator,
    gateway: gateway,
    errors: errors,
    lifecycle: lifecycle,
  );
}

class _CoordinatorHarness {
  const _CoordinatorHarness({
    required this.coordinator,
    required this.gateway,
    required this.errors,
    required this.lifecycle,
  });

  final AuthCoordinator coordinator;
  final _FakeAuthGateway gateway;
  final AppErrorController errors;
  final _SpyAuthLifecycleCoordinator lifecycle;
}

class _FakeAuthGateway implements AuthGateway, SessionQueryGateway {
  int restartCalls = 0;
  Object? restartError;
  int submitPhoneCalls = 0;
  Completer<void>? submitPhoneCompleter;

  @override
  Stream<TdAuthState> get authStates => const Stream<TdAuthState>.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {
    restartCalls++;
    if (restartError != null) {
      throw restartError!;
    }
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {
    submitPhoneCalls++;
    final completer = submitPhoneCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];
}

class _SpyAuthLifecycleCoordinator extends AuthLifecycleCoordinator {
  _SpyAuthLifecycleCoordinator({
    required super.auth,
    required super.errors,
    required super.errorMapper,
    required super.navigation,
  });

  int initializeCalls = 0;

  @override
  void initialize({required void Function(AuthStage stage) onStageChanged}) {
    initializeCalls++;
  }
}

class _FakeAuthNavigationPort implements AuthNavigationPort {
  @override
  void goToApp() {}

  @override
  void goToAuth() {}
}
