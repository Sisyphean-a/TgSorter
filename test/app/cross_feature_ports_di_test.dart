import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/core/di/auth_module.dart';
import 'package:tgsorter/app/core/di/pipeline_module.dart';
import 'package:tgsorter/app/core/di/settings_module.dart';
import 'package:tgsorter/app/core/di/tagging_module.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
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
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/features/shell/presentation/main_shell_page.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.testMode = true;
  });

  test(
    'auth and pipeline modules resolve only through cross-feature ports',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final authGateway = _ModuleAuthGateway();
      final pipelineSettings = _ModulePipelineSettingsReader();
      final pipelineGateway = _ModulePipelineGateway();

      Get.put<AppErrorController>(AppErrorController());
      Get.put<AuthGateway>(authGateway);
      Get.put<AuthSettingsPort>(_NoopAuthSettingsPort());
      Get.put<AuthNavigationPort>(_NoopAuthNavigationPort());

      expect(registerAuthModule, returnsNormally);
      expect(Get.find<AuthCoordinator>().auth, same(authGateway));

      Get.put<OperationJournalRepository>(OperationJournalRepository(prefs));
      Get.put<AuthStateGateway>(authGateway);
      Get.put<ConnectionStateGateway>(pipelineGateway);
      Get.put<MessageReadGateway>(pipelineGateway);
      Get.put<MediaGateway>(pipelineGateway);
      Get.put<ClassifyGateway>(pipelineGateway);
      Get.put<RecoveryGateway>(pipelineGateway);
      Get.put<PipelineSettingsReader>(pipelineSettings);
      Get.put<TaggingGateway>(pipelineGateway);

      expect(registerPipelineModule, returnsNormally);
      expect(Get.find<PipelineCoordinator>(), isNotNull);
      expect(Get.find<PipelineLogsPort>(), isA<PipelineLogsPort>());
      expect(registerTaggingModule, returnsNormally);
      expect(Get.find<TaggingCoordinator>(), isNotNull);
    },
  );

  test('app routes resolve pages through registered ports', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authGateway = _ModuleAuthGateway();
    final sessionGateway = _ModuleSessionGateway();
    final pipelineGateway = _ModulePipelineGateway();

    Get.put<SettingsRepository>(SettingsRepository(prefs));
    Get.put<AuthGateway>(authGateway);
    Get.put<SessionQueryGateway>(sessionGateway);
    Get.put<AppErrorController>(AppErrorController());

    registerSettingsModule();
    expect(Get.isRegistered<SettingsCoordinator>(), isTrue);
    expect(Get.isRegistered<AuthSettingsPort>(), isTrue);
    expect(Get.isRegistered<PipelineSettingsReader>(), isTrue);

    registerAuthModule();

    Get.put<OperationJournalRepository>(OperationJournalRepository(prefs));
    Get.put<AuthStateGateway>(authGateway);
    Get.put<ConnectionStateGateway>(pipelineGateway);
    Get.put<MessageReadGateway>(pipelineGateway);
    Get.put<MediaGateway>(pipelineGateway);
    Get.put<ClassifyGateway>(pipelineGateway);
    Get.put<RecoveryGateway>(pipelineGateway);
    Get.put<TaggingGateway>(pipelineGateway);
    registerPipelineModule();
    registerTaggingModule();

    final fakeRouteSettingsReader = _RoutePipelineSettingsReader();
    final fakeRouteLogsPort = _RoutePipelineLogsPort();
    Get.replace<PipelineSettingsReader>(fakeRouteSettingsReader);
    Get.replace<PipelineLogsPort>(fakeRouteLogsPort);

    final pages = buildAppPages();
    final authPage = pages
        .firstWhere((page) => page.name == AppRoutes.auth)
        .page();
    final appPage =
        pages.firstWhere((page) => page.name == AppRoutes.app).page()
            as MainShellPage;

    expect(authPage, isA<AuthPage>());
    expect(appPage.pipelineSettings, same(fakeRouteSettingsReader));
    expect(appPage.pipelineLogs, same(fakeRouteLogsPort));
    expect(appPage.tagging, same(Get.find<TaggingCoordinator>()));
  });
}

class _ModuleAuthGateway implements AuthGateway, AuthStateGateway {
  final _authStates = StreamController<TdAuthState>.broadcast();

  @override
  Stream<TdAuthState> get authStates => _authStates.stream;

  @override
  Future<void> restart() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}

class _NoopAuthSettingsPort implements AuthSettingsPort {
  @override
  ProxySettings get currentProxySettings => ProxySettings.empty;

  @override
  Future<void> saveProxySettings({
    required String server,
    required String port,
    required String username,
    required String password,
    bool restart = false,
  }) async {}
}

class _ModuleSessionGateway implements SessionQueryGateway {
  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];
}

class _RoutePipelineSettingsReader implements PipelineSettingsReader {
  @override
  AppSettings get currentSettings => AppSettings.defaults();

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => AppSettings.defaults().obs;
}

class _RoutePipelineLogsPort implements PipelineLogsPort {
  @override
  List<ClassifyOperationLog> get logsSnapshot => const [];
}

class _ModulePipelineSettingsReader implements PipelineSettingsReader {
  @override
  AppSettings get currentSettings => AppSettings.defaults();

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => AppSettings.defaults().obs;
}

class _ModulePipelineGateway
    implements
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway,
        TaggingGateway {
  final _connectionStates = StreamController<TdConnectionState>.broadcast();

  @override
  Stream<TdConnectionState> get connectionStates => _connectionStates.stream;

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async => throw UnimplementedError();

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async => const [];

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => null;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async => throw UnimplementedError();

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async => throw UnimplementedError();

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async =>
      ClassifyRecoverySummary.empty;

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}

  @override
  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  }) async => throw UnimplementedError();
}

class _NoopAuthNavigationPort implements AuthNavigationPort {
  @override
  void goToApp() {}
}
