import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/shell/presentation/main_shell_page.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/default_workbench.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets('main shell exposes workspace settings and logs destinations', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsGateway = _ShellSettingsGateway();
    final pipelineGateway = _ShellPipelineGateway();
    final settingsController = SettingsCoordinator(
      SettingsRepository(prefs),
      settingsGateway,
      auth: settingsGateway,
    );
    settingsController.onInit();
    settingsController.settings.value = const AppSettings(
      categories: [
        CategoryConfig(key: 'a', targetChatId: 1001, targetChatTitle: '收纳'),
      ],
      sourceChatId: 888,
      fetchDirection: MessageFetchDirection.latestFirst,
      forwardAsCopy: false,
      batchSize: 2,
      throttleMs: 0,
      proxy: ProxySettings.empty,
    );
    final errors = AppErrorController();
    final pipeline = PipelineCoordinator(
      authStateGateway: pipelineGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      classifyGateway: pipelineGateway,
      recoveryGateway: pipelineGateway,
      settingsReader: settingsController,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errors,
    );
    pipeline.currentMessage.value = PipelineMessage(
      id: 1,
      messageIds: const [1],
      sourceChatId: 888,
      preview: const MessagePreview(
        kind: MessagePreviewKind.text,
        title: '待分类消息',
      ),
    );
    pipeline.isOnline.value = true;
    pipeline.remainingCount.value = 7;
    final tagging = TaggingCoordinator(
      authStateGateway: pipelineGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      taggingGateway: pipelineGateway,
      settingsReader: settingsController,
      errorController: errors,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: MainShellPage(
          pipeline: pipeline,
          tagging: tagging,
          pipelineSettings: settingsController,
          errors: errors,
          settings: settingsController,
          pipelineLogs: pipeline,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('剩余 7'), findsOneWidget);
    expect(find.text('设置'), findsNothing);

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();

    final drawerSubtitle = tester.widget<Text>(find.text('主工作区导航'));
    expect(drawerSubtitle.style?.color, const Color(0xFF74808B));
    expect(find.text('转发工作台'), findsOneWidget);
    expect(find.text('标签工作台'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.byTooltip('打开导航'), findsOneWidget);

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();

    expect(find.text('操作日志'), findsAtLeastNWidgets(1));
    expect(find.text('失败中'), findsOneWidget);

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('转发工作台'));
    await tester.pumpAndSettle();

    expect(find.text('剩余 7'), findsOneWidget);
  });

  testWidgets(
    'main shell uses saved default workbench as initial landing page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Get.testMode = true;
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsGateway = _ShellSettingsGateway();
      final pipelineGateway = _ShellPipelineGateway();
      final settingsController = SettingsCoordinator(
        SettingsRepository(prefs),
        settingsGateway,
        auth: settingsGateway,
      );
      settingsController.onInit();
      settingsController.settings.value = const AppSettings(
        categories: [
          CategoryConfig(key: 'a', targetChatId: 1001, targetChatTitle: '收纳'),
        ],
        sourceChatId: 888,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 2,
        throttleMs: 0,
        proxy: ProxySettings.empty,
        defaultWorkbench: AppDefaultWorkbench.tagging,
      );
      final errors = AppErrorController();
      final pipeline = PipelineCoordinator(
        authStateGateway: pipelineGateway,
        connectionStateGateway: pipelineGateway,
        messageReadGateway: pipelineGateway,
        mediaGateway: pipelineGateway,
        classifyGateway: pipelineGateway,
        recoveryGateway: pipelineGateway,
        settingsReader: settingsController,
        journalRepository: OperationJournalRepository(prefs),
        errorController: errors,
      );
      pipeline.currentMessage.value = PipelineMessage(
        id: 1,
        messageIds: const [1],
        sourceChatId: 888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: '待分类消息',
        ),
      );
      pipeline.isOnline.value = true;
      final tagging = TaggingCoordinator(
        authStateGateway: pipelineGateway,
        connectionStateGateway: pipelineGateway,
        messageReadGateway: pipelineGateway,
        mediaGateway: pipelineGateway,
        taggingGateway: pipelineGateway,
        settingsReader: settingsController,
        errorController: errors,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: MainShellPage(
            pipeline: pipeline,
            tagging: tagging,
            pipelineSettings: settingsController,
            errors: errors,
            settings: settingsController,
            pipelineLogs: pipeline,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('标签工作台'), findsOneWidget);
      expect(find.text('待分类消息'), findsNothing);
    },
  );

  testWidgets(
    'mobile settings proxy edit and save does not trigger framework exceptions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Get.testMode = true;
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsGateway = _ShellSettingsGateway();
      final pipelineGateway = _ShellPipelineGateway();
      final settingsController = SettingsCoordinator(
        SettingsRepository(prefs),
        settingsGateway,
        auth: settingsGateway,
      );
      settingsController.onInit();
      final errors = AppErrorController();
      final pipeline = PipelineCoordinator(
        authStateGateway: pipelineGateway,
        connectionStateGateway: pipelineGateway,
        messageReadGateway: pipelineGateway,
        mediaGateway: pipelineGateway,
        classifyGateway: pipelineGateway,
        recoveryGateway: pipelineGateway,
        settingsReader: settingsController,
        journalRepository: OperationJournalRepository(prefs),
        errorController: errors,
      );
      final tagging = TaggingCoordinator(
        authStateGateway: pipelineGateway,
        connectionStateGateway: pipelineGateway,
        messageReadGateway: pipelineGateway,
        mediaGateway: pipelineGateway,
        taggingGateway: pipelineGateway,
        settingsReader: settingsController,
        errorController: errors,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark(),
          home: MainShellPage(
            pipeline: pipeline,
            tagging: tagging,
            pipelineSettings: settingsController,
            errors: errors,
            settings: settingsController,
            pipelineLogs: pipeline,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('打开导航'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('连接与网络'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '代理服务器'),
        '127.0.0.1',
      );
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, '代理端口'), '7890');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('设置已保存'), findsOneWidget);
    },
  );

  testWidgets('logs page app bar does not inherit settings detail actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsGateway = _ShellSettingsGateway();
    final pipelineGateway = _ShellPipelineGateway();
    final settingsController = SettingsCoordinator(
      SettingsRepository(prefs),
      settingsGateway,
      auth: settingsGateway,
    );
    settingsController.onInit();
    final errors = AppErrorController();
    final pipeline = PipelineCoordinator(
      authStateGateway: pipelineGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      classifyGateway: pipelineGateway,
      recoveryGateway: pipelineGateway,
      settingsReader: settingsController,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errors,
    );
    final tagging = TaggingCoordinator(
      authStateGateway: pipelineGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      taggingGateway: pipelineGateway,
      settingsReader: settingsController,
      errorController: errors,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark(),
        home: MainShellPage(
          pipeline: pipeline,
          tagging: tagging,
          pipelineSettings: settingsController,
          errors: errors,
          settings: settingsController,
          pipelineLogs: pipeline,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '代理服务器'),
      '127.0.0.1',
    );
    await tester.pumpAndSettle();
    expect(find.text('保存'), findsOneWidget);

    await tester.dragFrom(const Offset(0, 200), const Offset(320, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日志'));
    await tester.pumpAndSettle();

    expect(find.text('操作日志'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('打开导航'), findsOneWidget);
    expect(find.byTooltip('返回'), findsNothing);
    expect(find.text('保存'), findsNothing);

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    expect(find.text('连接与网络'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });
}

class _ShellSettingsGateway implements AuthGateway, SessionQueryGateway {
  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [
    SelectableChat(id: -1001, title: '频道一'),
  ];

  @override
  Future<void> restart() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}

class _ShellPipelineGateway
    implements
        AuthStateGateway,
        ConnectionStateGateway,
        ClassifyGateway,
        MessageReadGateway,
        MediaGateway,
        RecoveryGateway,
        TaggingGateway {
  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Stream<TdConnectionState> get connectionStates => const Stream.empty();

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
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}

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
