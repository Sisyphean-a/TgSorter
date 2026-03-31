import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/pages/auth_page.dart';
import 'package:tgsorter/app/pages/pipeline_page.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  testWidgets('Auth ready navigates to pipeline page', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1280, 2200);
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController(SettingsRepository(prefs));
    final service = _IntegrationFakeGateway();
    final pipeline = PipelineController(
      service: service,
      settingsController: settings,
      journalRepository: OperationJournalRepository(prefs),
    );
    final auth = AuthController(service);

    Get.put<SettingsController>(settings);
    Get.put<PipelineController>(pipeline);
    Get.put<AuthController>(auth);
    settings.onInit();
    pipeline.onInit();
    auth.onInit();
    service.emitConnectionReady();

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/auth',
        getPages: [
          GetPage(name: '/auth', page: () => AuthPage()),
          GetPage(name: '/pipeline', page: () => PipelinePage()),
        ],
      ),
    );
    await tester.pump();
    service.emitAuthState(const AuthorizationStateReady());
    await tester.pumpAndSettle();

    expect(find.text('TgSorter 分发流水线'), findsOneWidget);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}

class _IntegrationFakeGateway implements TelegramGateway {
  final _authController = StreamController<AuthorizationState>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();

  @override
  Stream<AuthorizationState> get authStates => _authController.stream;

  @override
  Stream<ConnectionState> get connectionStates => _connectionController.stream;

  void emitAuthState(AuthorizationState state) {
    _authController.add(state);
  }

  void emitConnectionReady() {
    _connectionController.add(const ConnectionStateReady());
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<PipelineMessage?> fetchNextSavedMessage({
    required MessageFetchDirection direction,
  }) async {
    return null;
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int messageId,
    required int targetChatId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required int targetMessageId,
  }) async {
    throw UnimplementedError();
  }
}
