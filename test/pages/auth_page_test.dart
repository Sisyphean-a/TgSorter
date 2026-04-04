import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/core/di/auth_module.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/brand_app_bar.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('auth page uses shared shell and branded auth summary', (
    tester,
  ) async {
    await _pumpAuthPage(tester);

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(BrandAppBar), findsOneWidget);
    expect(find.text('安全登录'), findsOneWidget);
    expect(find.text('使用 TDLib Userbot 登录 Telegram'), findsOneWidget);
    expect(find.text('登录流程保持简洁，代理与验证码操作集中在同一页面。'), findsOneWidget);
  });

  testWidgets('auth page animates between auth stages', (tester) async {
    final gateway = _FakeAuthGateway();
    await _pumpAuthPage(tester, gateway: gateway);

    gateway.emitState(
      const TdAuthState(
        kind: TdAuthStateKind.waitPhoneNumber,
        rawType: 'authorizationStateWaitPhoneNumber',
      ),
    );
    await tester.pump();

    expect(find.byType(AnimatedSwitcher), findsWidgets);
    expect(find.text('手机号登录'), findsOneWidget);

    gateway.emitState(
      const TdAuthState(
        kind: TdAuthStateKind.waitCode,
        rawType: 'authorizationStateWaitCode',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('输入验证码'), findsOneWidget);
  });

  test('auth DI module resolves by capability ports (no TelegramGateway)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authGateway = _FakeAuthGateway();
    final errors = AppErrorController();
    final settings = SettingsCoordinator(
      SettingsRepository(prefs),
      authGateway,
      auth: authGateway,
    );

    Get.put<AuthGateway>(authGateway);
    Get.put<AppErrorController>(errors);
    Get.put<SettingsCoordinator>(settings);

    expect(registerAuthModule, returnsNormally);
    final coordinator = Get.find<AuthCoordinator>();
    expect(coordinator.auth, same(authGateway));
  });
}

Future<void> _pumpAuthPage(
  WidgetTester tester, {
  _FakeAuthGateway? gateway,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = gateway ?? _FakeAuthGateway();
  final errors = AppErrorController();
  final settings = SettingsCoordinator(
    SettingsRepository(prefs),
    service,
    auth: service,
  );
  final auth = AuthCoordinator(service, errors, settings);

  Get.put<AppErrorController>(errors);
  Get.put<SettingsCoordinator>(settings);
  Get.put<AuthCoordinator>(auth);
  settings.onInit();
  auth.onInit();

  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.dark(),
      home: AuthPage(auth: auth, errors: errors, settings: settings),
    ),
  );
  await tester.pump();
}

class _FakeAuthGateway implements AuthGateway, SessionQueryGateway {
  final _authController = StreamController<TdAuthState>.broadcast();

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  void emitState(TdAuthState state) {
    _authController.add(state);
  }

  @override
  Future<void> start() async {}

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
