import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/pages/settings_page.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('renders grouped settings page with page-level actions', (
    tester,
  ) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: -1001, title: '频道一'),
        SelectableChat(id: -1002, title: '频道二'),
      ],
    );

    expect(find.text('基础流程'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('分类管理'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('分类管理'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('连接设置'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('连接设置'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('操作与工具'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('操作与工具'), findsOneWidget);
    expect(find.text('保存更改'), findsOneWidget);
    expect(find.text('放弃更改'), findsOneWidget);
    expect(find.text('保存代理'), findsNothing);
    expect(find.text('批处理设置已保存'), findsNothing);
    expect(find.text('保存'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('新增分类'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('新增分类'), findsOneWidget);
    expect(controller.draftSettings.value.categories, isEmpty);
    await tester.scrollUntilVisible(
      find.text('预加载后续预览'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('预加载后续预览'), findsOneWidget);
  });

  testWidgets('edits stay in draft until save and can be discarded', (
    tester,
  ) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('最新优先'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最旧优先').last);
    await tester.pumpAndSettle();

    expect(controller.isDirty.value, isTrue);
    expect(controller.savedSettings.value.fetchDirection, MessageFetchDirection.latestFirst);
    expect(controller.draftSettings.value.fetchDirection, MessageFetchDirection.oldestFirst);

    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();

    expect(controller.isDirty.value, isFalse);
    expect(controller.draftSettings.value.fetchDirection, MessageFetchDirection.latestFirst);
  });

  testWidgets('does not overflow on narrow screen with category rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: -1001, title: '星空'),
        SelectableChat(id: -1002, title: 'mi_ASMR'),
        SelectableChat(id: -1003, title: '艺术'),
      ],
      initialSettings: const AppSettings(
        categories: [
          CategoryConfig(key: 'cat_1', targetChatId: -1001, targetChatTitle: '星空'),
          CategoryConfig(key: 'cat_2', targetChatId: -1002, targetChatTitle: 'mi_ASMR'),
          CategoryConfig(key: 'cat_3', targetChatId: -1003, targetChatTitle: '艺术'),
        ],
        sourceChatId: null,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 5,
        throttleMs: 1200,
        proxy: ProxySettings.empty,
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<SettingsController> _pumpSettingsPage(
  WidgetTester tester, {
  required List<SelectableChat> chats,
  AppSettings? initialSettings,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final controller = SettingsController(
    SettingsRepository(prefs),
    _SettingsPageFakeGateway(chats),
  );
  controller.onInit();
  if (initialSettings != null) {
    controller.settings.value = initialSettings;
    controller.draftSettings.value = initialSettings;
    controller.isDirty.value = false;
  }
  Get.put<SettingsController>(controller);

  await tester.pumpWidget(
    const GetMaterialApp(
      home: SettingsPage(),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _SettingsPageFakeGateway implements TelegramGateway {
  _SettingsPageFakeGateway(this._chats);

  final List<SelectableChat> _chats;

  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Stream<TdConnectionState> get connectionStates => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<List<SelectableChat>> listSelectableChats() async => _chats;

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
  }) async {}
}
