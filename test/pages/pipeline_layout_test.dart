import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_session_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';

void main() {
  group('PipelineLayoutSwitch', () {
    testWidgets('renders desktop child on wide layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PipelineLayoutSwitch(
              mobile: const SizedBox(key: Key('mobile-layout')),
              desktop: const SizedBox(key: Key('desktop-layout')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('desktop-layout')), findsOneWidget);
      expect(find.byKey(const Key('mobile-layout')), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders mobile child on narrow layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PipelineLayoutSwitch(
              mobile: const SizedBox(key: Key('mobile-layout')),
              desktop: const SizedBox(key: Key('desktop-layout')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('mobile-layout')), findsOneWidget);
      expect(find.byKey(const Key('desktop-layout')), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('PipelinePage desktop layout', () {
    late SettingsCoordinator settingsController;
    late PipelineCoordinator pipelineController;
    late AppErrorController errorController;

    setUp(() async {
      Get.testMode = true;
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsGateway = _PipelineLayoutSettingsGateway();
      final pipelineGateway = _PipelineLayoutFakeGateway();
      settingsController = SettingsCoordinator(
        SettingsRepository(prefs),
        settingsGateway,
        auth: settingsGateway,
      );
      settingsController.onInit();
      const seededSettings = AppSettings(
        categories: [
          CategoryConfig(key: 'a', targetChatId: 1001, targetChatTitle: '收纳'),
          CategoryConfig(key: 'b', targetChatId: 1002, targetChatTitle: '归档'),
        ],
        sourceChatId: 888,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 2,
        throttleMs: 0,
        proxy: ProxySettings.empty,
      );
      settingsController.savedSettings.value = seededSettings;
      settingsController.draftSettings.value = seededSettings;
      errorController = AppErrorController();
      pipelineController = PipelineCoordinator(
        authStateGateway: pipelineGateway,
        connectionStateGateway: pipelineGateway,
        messageReadGateway: pipelineGateway,
        mediaGateway: pipelineGateway,
        classifyGateway: pipelineGateway,
        recoveryGateway: pipelineGateway,
        settingsReader: settingsController,
        journalRepository: OperationJournalRepository(prefs),
        errorController: errorController,
      );
      pipelineController.currentMessage.value = PipelineMessage(
        id: 1,
        messageIds: const [1],
        sourceChatId: 888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.text,
          title: '待分类消息',
        ),
      );
      pipelineController.isOnline.value = true;
      pipelineController.remainingCount.value = 32;
      Get.put(settingsController);
      Get.put(pipelineController);
      Get.put(errorController);
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('uses brand app bar and split workspace panels', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.light(),
          home: PipelinePage(
            pipeline: pipelineController,
            settings: settingsController,
            errors: errorController,
          ),
        ),
      );

      expect(find.text('TgSorter'), findsOneWidget);
      expect(find.byType(StatusBadge), findsAtLeastNWidgets(1));
      expect(
        find.byKey(const Key('pipeline-desktop-workspace')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('desktop-message-panel')), findsOneWidget);
      expect(find.byKey(const Key('desktop-action-panel')), findsOneWidget);
      expect(find.byKey(const Key('desktop-operations-panel')), findsOneWidget);
      expect(find.text('消息 #1'), findsOneWidget);
      expect(find.text('来源 888'), findsOneWidget);
      expect(find.text('共 1 条'), findsOneWidget);
      expect(find.text('快捷键映射'), findsNothing);
      expect(find.text('查看状态、快捷键与辅助操作'), findsNothing);
      expect(find.text('控制台'), findsNothing);
      expect(find.text('消息工作区'), findsNothing);
      expect(find.text('操作面板'), findsNothing);
      final appBarMaterial = tester.widget<Material>(
        find
            .byWidgetPredicate(
              (widget) => widget is Material && widget.child is SafeArea,
            )
            .first,
      );
      expect(appBarMaterial.color, const Color(0xFFF4F5F7));
      final messagePanelBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('desktop-message-panel')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final panelDecoration = messagePanelBox.decoration as BoxDecoration;
      expect(panelDecoration.color, const Color(0xFFFFFFFF));
      expect(find.byType(AnimatedSwitcher), findsWidgets);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('desktop next button reacts when navigation state changes', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark(),
          home: PipelinePage(
            pipeline: pipelineController,
            settings: settingsController,
            errors: errorController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nextFinder = find.widgetWithText(OutlinedButton, '下一条');
      final disabled = tester.widget<OutlinedButton>(nextFinder);
      expect(disabled.onPressed, isNull);

      pipelineController.runtimeState.navigation.value =
          const NavigationAvailability(
            canShowPrevious: false,
            next: NextAvailability.fetchable,
          );
      await tester.pump();

      final enabled = tester.widget<OutlinedButton>(nextFinder);
      expect(enabled.onPressed, isNotNull);
    });
  });

  testWidgets('pipeline page keeps compact mobile header with remaining only', (
    tester,
  ) async {
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsGateway = _PipelineLayoutSettingsGateway();
    final pipelineGateway = _PipelineLayoutFakeGateway();
    final settingsController = SettingsCoordinator(
      SettingsRepository(prefs),
      settingsGateway,
      auth: settingsGateway,
    );
    settingsController.onInit();
    settingsController.settings.value = const AppSettings(
      categories: [],
      sourceChatId: 888,
      fetchDirection: MessageFetchDirection.latestFirst,
      forwardAsCopy: false,
      batchSize: 2,
      throttleMs: 0,
      proxy: ProxySettings.empty,
    );
    final errorController = AppErrorController();
    final pipelineController = PipelineCoordinator(
      authStateGateway: pipelineGateway,
      connectionStateGateway: pipelineGateway,
      messageReadGateway: pipelineGateway,
      mediaGateway: pipelineGateway,
      classifyGateway: pipelineGateway,
      recoveryGateway: pipelineGateway,
      settingsReader: settingsController,
      journalRepository: OperationJournalRepository(prefs),
      errorController: errorController,
    );
    pipelineController.isOnline.value = false;
    pipelineController.processing.value = false;
    pipelineController.remainingCount.value = 32;
    Get.put(settingsController);
    Get.put(pipelineController);
    Get.put(errorController);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      Get.reset();
    });

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark(),
        home: PipelinePage(
          pipeline: pipelineController,
          settings: settingsController,
          errors: errorController,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TgSorter'), findsOneWidget);
    expect(find.text('剩余 32'), findsOneWidget);
    expect(find.text('离线'), findsNothing);
    expect(find.text('待命'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _PipelineLayoutSettingsGateway
    implements AuthGateway, SessionQueryGateway {
  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

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

class _PipelineLayoutFakeGateway
    implements
        AuthStateGateway,
        ConnectionStateGateway,
        ClassifyGateway,
        MessageReadGateway,
        MediaGateway,
        RecoveryGateway {
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
}
