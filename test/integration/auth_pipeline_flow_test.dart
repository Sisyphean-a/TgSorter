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
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

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

    await tester.enterText(
      find.widgetWithText(TextField, '代理服务器'),
      '127.0.0.1',
    );
    await tester.enterText(find.widgetWithText(TextField, '代理端口'), '7897');
    await tester.tap(find.text('保存代理并重试启动'));
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

class _IntegrationAuthGateway implements AuthGateway, AuthStateGateway {
  final _authController = StreamController<TdAuthState>.broadcast();
  int restartCalls = 0;

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  void emitAuthState(TdAuthState state) {
    _authController.add(state);
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {
    restartCalls++;
  }

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}

class _IntegrationSettingsGateway implements SessionQueryGateway {
  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];
}

class _NoopAuthNavigationPort implements AuthNavigationPort {
  @override
  void goToApp() {}
}

class _IntegrationPipelineGateway
    implements
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway,
        TaggingGateway {
  final _connectionController = StreamController<TdConnectionState>.broadcast();

  @override
  Stream<TdConnectionState> get connectionStates =>
      _connectionController.stream;

  void emitConnectionReady() {
    _connectionController.add(
      const TdConnectionState(
        kind: TdConnectionStateKind.ready,
        rawType: 'connectionStateReady',
      ),
    );
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    return const [];
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    return null;
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    return ClassifyRecoverySummary.empty;
  }

  @override
  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  }) async {
    throw UnimplementedError();
  }
}
