import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/pages/pipeline_page.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';
import 'package:tgsorter/app/widgets/status_badge.dart';

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
    late SettingsController settingsController;
    late PipelineController pipelineController;
    late AppErrorController errorController;

    setUp(() async {
      Get.testMode = true;
      Get.reset();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _PipelineLayoutFakeGateway();
      settingsController = SettingsController(
        SettingsRepository(prefs),
        gateway,
      );
      settingsController.onInit();
      settingsController.settings.value = const AppSettings(
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
      errorController = AppErrorController();
      pipelineController = PipelineController(
        service: gateway,
        settingsProvider: settingsController,
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
          theme: AppTheme.dark(),
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
      expect(find.byType(AnimatedSwitcher), findsWidgets);
      await tester.binding.setSurfaceSize(null);
    });
  });

  testWidgets('pipeline page keeps compact mobile header with remaining only', (
    tester,
  ) async {
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gateway = _PipelineLayoutFakeGateway();
    final settingsController = SettingsController(
      SettingsRepository(prefs),
      gateway,
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
    final pipelineController = PipelineController(
      service: gateway,
      settingsProvider: settingsController,
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

class _PipelineLayoutFakeGateway implements TelegramGateway {
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
  Future<List<SelectableChat>> listSelectableChats() async => const [];

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
  Future<void> restart() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}
}
