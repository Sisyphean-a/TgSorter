import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

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

  test('saveProxyAndRetry does not restart when saving proxy fails', () async {
    final harness = await _buildHarness();
    harness.settings.failOnSave = StateError('save failed');

    await harness.coordinator.saveProxyAndRetry(
      server: '127.0.0.1',
      port: '7897',
      username: '',
      password: '',
    );

    expect(harness.gateway.restartCalls, 0);
    expect(harness.errors.currentError.value, contains('启动失败'));
  });

  test('saveProxyAndRetry reports restart failures after persisting settings', () async {
    final harness = await _buildHarness();
    harness.gateway.restartError = TdlibFailure.transport(
      message: 'NETWORK_UNREACHABLE',
      request: 'restart',
      phase: TdlibPhase.startup,
    );

    await harness.coordinator.saveProxyAndRetry(
      server: '127.0.0.1',
      port: '7897',
      username: '',
      password: '',
    );

    expect(harness.settings.operations, ['saveProxySettings']);
    expect(harness.gateway.restartCalls, 1);
    expect(harness.errors.currentError.value, contains('启动失败'));
    expect(harness.errors.currentError.value, contains('网络异常：NETWORK_UNREACHABLE'));
  });
}

Future<_CoordinatorHarness> _buildHarness() async {
  final prefs = await SharedPreferences.getInstance();
  final gateway = _FakeAuthGateway();
  final errors = AppErrorController();
  final settings = _FakeSettingsCoordinator(
    SettingsRepository(prefs),
    gateway,
    auth: gateway,
  )..onInit();
  final lifecycle = _SpyAuthLifecycleCoordinator(
    auth: gateway,
    errors: errors,
    errorMapper: const AuthErrorMapper(),
    navigation: _FakeAuthNavigationPort(),
  );
  final coordinator = AuthCoordinator(
    gateway,
    errors,
    settings,
    lifecycle: lifecycle,
  );
  return _CoordinatorHarness(
    coordinator: coordinator,
    gateway: gateway,
    errors: errors,
    settings: settings,
    lifecycle: lifecycle,
  );
}

class _CoordinatorHarness {
  const _CoordinatorHarness({
    required this.coordinator,
    required this.gateway,
    required this.errors,
    required this.settings,
    required this.lifecycle,
  });

  final AuthCoordinator coordinator;
  final _FakeAuthGateway gateway;
  final AppErrorController errors;
  final _FakeSettingsCoordinator settings;
  final _SpyAuthLifecycleCoordinator lifecycle;
}

class _FakeAuthGateway implements AuthGateway, SessionQueryGateway {
  int restartCalls = 0;
  Object? restartError;

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
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];
}

class _FakeSettingsCoordinator extends SettingsCoordinator {
  _FakeSettingsCoordinator(
    super.repository,
    super.sessions, {
    super.auth,
  });

  final operations = <String>[];
  Object? failOnSave;

  @override
  Future<void> saveProxySettings({
    required String server,
    required String port,
    required String username,
    required String password,
    bool restart = false,
  }) async {
    operations.add('saveProxySettings');
    if (failOnSave != null) {
      throw failOnSave!;
    }
    await super.saveProxySettings(
      server: server,
      port: port,
      username: username,
      password: password,
      restart: restart,
    );
  }
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
  void goToPipeline() {}
}
