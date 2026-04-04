import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/core/di/pipeline_module.dart';
import 'package:tgsorter/app/core/di/settings_module.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  testWidgets('Auth ready navigates to pipeline page', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 2200);
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _IntegrationFakeGateway();
    final errors = AppErrorController();
    final settings = SettingsCoordinator(
      SettingsRepository(prefs),
      service,
      auth: service,
    );
    final pipeline = PipelineCoordinator(
      authStateGateway: service,
      connectionStateGateway: service,
      messageReadGateway: service,
      mediaGateway: service,
      classifyGateway: service,
      recoveryGateway: service,
      settingsReader: settings,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errors,
    );
    final auth = AuthCoordinator(service, errors, settings);

    Get.put<AppErrorController>(errors);
    Get.put<SettingsCoordinator>(settings);
    Get.put<PipelineCoordinator>(pipeline);
    Get.put<AuthCoordinator>(auth);
    settings.onInit();
    pipeline.onInit();
    auth.onInit();
    service.emitConnectionReady();

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/auth',
        getPages: [
          GetPage(
            name: '/auth',
            page: () =>
                AuthPage(auth: auth, errors: errors, settings: settings),
          ),
          GetPage(
            name: '/pipeline',
            page: () => PipelinePage(
              pipeline: pipeline,
              settings: settings,
              errors: errors,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    service.emitAuthState(
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
    final service = _IntegrationFakeGateway();
    final errors = AppErrorController();
    final settings = SettingsCoordinator(
      SettingsRepository(prefs),
      service,
      auth: service,
    );
    final pipeline = PipelineCoordinator(
      authStateGateway: service,
      connectionStateGateway: service,
      messageReadGateway: service,
      mediaGateway: service,
      classifyGateway: service,
      recoveryGateway: service,
      settingsReader: settings,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errors,
    );
    final auth = AuthCoordinator(service, errors, settings);

    Get.put<AppErrorController>(errors);
    Get.put<SettingsCoordinator>(settings);
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
            page: () =>
                AuthPage(auth: auth, errors: errors, settings: settings),
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
    expect(service.restartCalls, 1);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  test('settings/pipeline DI modules resolve by capability ports', () async {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _IntegrationFakeGateway();

    Get.put<SettingsRepository>(SettingsRepository(prefs));
    Get.put<AuthGateway>(service);
    Get.put<SessionQueryGateway>(service);

    expect(registerSettingsModule, returnsNormally);
    expect(Get.isRegistered<SettingsCoordinator>(), isTrue);

    Get.put<OperationJournalRepository>(OperationJournalRepository(prefs));
    Get.put<AppErrorController>(AppErrorController());
    Get.put<AuthStateGateway>(service);
    Get.put<ConnectionStateGateway>(service);
    Get.put<MessageReadGateway>(service);
    Get.put<MediaGateway>(service);
    Get.put<ClassifyGateway>(service);
    Get.put<RecoveryGateway>(service);

    expect(registerPipelineModule, returnsNormally);
    expect(Get.isRegistered<PipelineCoordinator>(), isTrue);
  });
}

class _IntegrationFakeGateway
    implements
        AuthGateway,
        SessionQueryGateway,
        AuthStateGateway,
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway {
  final _authController = StreamController<TdAuthState>.broadcast();
  final _connectionController = StreamController<TdConnectionState>.broadcast();
  int restartCalls = 0;

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  @override
  Stream<TdConnectionState> get connectionStates => _connectionController.stream;

  void emitAuthState(TdAuthState state) {
    _authController.add(state);
  }

  void emitConnectionReady() {
    _connectionController.add(
      const TdConnectionState(
        kind: TdConnectionStateKind.ready,
        rawType: 'connectionStateReady',
      ),
    );
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

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

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
}
