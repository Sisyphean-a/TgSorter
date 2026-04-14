import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/core/di/auth_module.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/features/auth/ports/auth_settings_port.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/login_alerts/application/login_alert_workbench_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/shell/presentation/main_shell_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';
import 'package:tgsorter/app/services/login_alert_repository.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

part 'auth_pipeline_flow_test_fakes.dart';

void main() {
  testWidgets('Auth ready navigates to app shell', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 2200);
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authGateway = _IntegrationAuthGateway();
    final settingsGateway = _IntegrationSettingsGateway();
    final pipelineGateway = _IntegrationPipelineGateway();
    final errors = AppErrorController();
    final settings = SettingsCoordinator(
      SettingsRepository(prefs),
      settingsGateway,
      auth: authGateway,
    );
    final pipeline = PipelineCoordinator(
      authStateGateway: authGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      classifyGateway: pipelineGateway,
      recoveryGateway: pipelineGateway,
      settingsReader: settings,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errors,
    );
    final tagging = TaggingCoordinator(
      authStateGateway: authGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      taggingGateway: pipelineGateway,
      settingsReader: settings,
      errorController: errors,
    );
    Get.put<AppErrorController>(errors);
    Get.put<AuthGateway>(authGateway);
    Get.put<AuthSettingsPort>(settings);
    Get.put<PipelineCoordinator>(pipeline);
    expect(registerAuthModule, returnsNormally);
    final auth = Get.find<AuthCoordinator>();
    final downloads = DownloadWorkbenchController(
      sessions: settingsGateway,
      settings: settings,
      sync: const NoopDownloadSyncPort(),
    )..onInit();
    final loginAlerts = LoginAlertWorkbenchController(
      updates: const Stream<Map<String, dynamic>>.empty(),
      repository: LoginAlertRepository(prefs),
    )..onInit();
    settings.onInit();
    pipeline.onInit();
    pipelineGateway.emitConnectionReady();

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/auth',
        getPages: [
          GetPage(
            name: '/auth',
            page: () => AuthPage(auth: auth, errors: errors),
          ),
          GetPage(
            name: '/app',
            page: () => MainShellPage(
              pipeline: pipeline,
              tagging: tagging,
              downloads: downloads,
              loginAlerts: loginAlerts,
              pipelineSettings: settings,
              errors: errors,
              settings: settings,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    authGateway.emitAuthState(
      const TdAuthState(
        kind: TdAuthStateKind.ready,
        rawType: 'authorizationStateReady',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TgSorter'), findsOneWidget);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('save proxy and retry persists settings then restarts tdlib', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 2200);
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authGateway = _IntegrationAuthGateway();
    final settingsGateway = _IntegrationSettingsGateway();
    final pipelineGateway = _IntegrationPipelineGateway();
    final errors = AppErrorController();
    final settings = SettingsCoordinator(
      SettingsRepository(prefs),
      settingsGateway,
      auth: authGateway,
    );
    final pipeline = PipelineCoordinator(
      authStateGateway: authGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      classifyGateway: pipelineGateway,
      recoveryGateway: pipelineGateway,
      settingsReader: settings,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errors,
    );
    final auth = AuthCoordinator(
      authGateway,
      errors,
      settings,
      lifecycle: AuthLifecycleCoordinator(
        auth: authGateway,
        errors: errors,
        errorMapper: const AuthErrorMapper(),
        navigation: _NoopAuthNavigationPort(),
      ),
    );

    Get.put<AppErrorController>(errors);
    Get.put<AuthSettingsPort>(settings);
    Get.put<PipelineCoordinator>(pipeline);
    Get.put<AuthCoordinator>(auth);
    settings.onInit();
    pipeline.onInit();
    auth.onInit();

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/auth',
        getPages: [
          GetPage(
            name: '/auth',
            page: () => AuthPage(auth: auth, errors: errors),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('代理配置'));
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
      find.widgetWithText(TextField, '代理服务器'),
      '127.0.0.1',
    );
    await tester.enterText(find.widgetWithText(TextField, '代理端口'), '7897');
    final saveProxyButton = find.widgetWithText(FilledButton, '保存代理并重试启动');
    await tester.ensureVisible(saveProxyButton);
    await tester.pump();
    final saveButton = tester.widget<FilledButton>(saveProxyButton);
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!.call();
    await tester.pump();

    expect(prefs.getString('tdlib_proxy_server'), '127.0.0.1');
    expect(prefs.getInt('tdlib_proxy_port'), 7897);
    expect(authGateway.restartCalls, 1);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
