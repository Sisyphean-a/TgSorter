import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_common_editors.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_list_section.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/shared/presentation/widgets/sticky_action_bar.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('renders telegram style settings sections without inline logs', (
    tester,
  ) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: -1001, title: '频道一'),
        SelectableChat(id: -1002, title: '频道二'),
      ],
    );

    expect(find.text('转发区设置'), findsOneWidget);
    expect(find.text('新增分类'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('标签区设置'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('标签区设置'), findsOneWidget);
    expect(find.text('标签来源会话'), findsOneWidget);
    expect(find.text('默认标签组'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('通用设置'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('通用设置'), findsOneWidget);
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('工作流'), findsNothing);
    expect(find.text('分类'), findsNothing);
    expect(find.text('连接与代理'), findsNothing);
    expect(find.text('快捷键与工具'), findsNothing);
    expect(find.text('最近操作'), findsNothing);
    expect(find.text('保存更改'), findsOneWidget);
    expect(find.text('放弃更改'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.byType(StickyActionBar), findsOneWidget);
    expect(find.text('保存代理'), findsNothing);
    expect(find.text('批处理设置已保存'), findsNothing);
    expect(find.text('保存'), findsNothing);
    expect(controller.draftSettings.value.categories, isEmpty);
    expect(find.text('预加载后续预览'), findsNothing);
    final firstSection = find.byType(SettingsListSection).first;
    final sectionBox = tester.widget<DecoratedBox>(
      find.descendant(of: firstSection, matching: find.byType(DecoratedBox)).first,
    );
    final decoration = sectionBox.decoration as BoxDecoration;
    final border = decoration.border! as Border;
    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(border.top.color, const Color(0xFFD9E1E8));
  });

  testWidgets('default tag group can add and remove a tag', (tester) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '添加标签'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '新增标签'), '摄影');
    await tester.pump();
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '添加标签'),
    );
    addButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(
      controller.draftSettings.value.tagGroups.first.tags.single.name,
      '摄影',
    );
    await tester.scrollUntilVisible(
      find.text('#摄影', skipOffstage: false),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('#摄影'), findsOneWidget);

    await tester.tap(find.byTooltip('删除标签 #摄影'));
    await tester.pumpAndSettle();

    expect(find.text('#摄影'), findsNothing);
    expect(controller.draftSettings.value.tagGroups.first.tags, isEmpty);
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
    expect(
      controller.savedSettings.value.fetchDirection,
      MessageFetchDirection.latestFirst,
    );
    expect(
      controller.draftSettings.value.fetchDirection,
      MessageFetchDirection.oldestFirst,
    );

    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();

    expect(controller.isDirty.value, isFalse);
    expect(
      controller.draftSettings.value.fetchDirection,
      MessageFetchDirection.latestFirst,
    );
  });

  testWidgets(
    'shows partial success message when save succeeds but restart fails',
    (tester) async {
      final gateway = _SettingsPageFakeGateway(const [
        SelectableChat(id: -1001, title: '频道一'),
      ])..restartError = StateError('restart failed');
      final controller = await _pumpSettingsPage(
        tester,
        chats: const [SelectableChat(id: -1001, title: '频道一')],
        gateway: gateway,
      );

      await tester.tap(find.text('最新优先'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('最旧优先').last);
      await tester.pumpAndSettle();

      controller.updateProxyDraft(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
      );
      await tester.pump();

      await tester.tap(find.text('保存更改'));
      await tester.pump();

      expect(find.textContaining('设置已保存，但重启失败'), findsOneWidget);
      expect(find.textContaining('保存失败'), findsNothing);
    },
  );

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
          CategoryConfig(
            key: 'cat_1',
            targetChatId: -1001,
            targetChatTitle: '星空',
          ),
          CategoryConfig(
            key: 'cat_2',
            targetChatId: -1002,
            targetChatTitle: 'mi_ASMR',
          ),
          CategoryConfig(
            key: 'cat_3',
            targetChatId: -1003,
            targetChatTitle: '艺术',
          ),
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

  testWidgets('source chat label sits above the input border', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SourceChatDraftEditor(
              sourceChatId: null,
              chats: const [],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final inputTop = tester
        .getRect(find.byType(DropdownButtonFormField<int?>))
        .top;
    final labelBottom = tester.getRect(find.text('来源会话')).bottom;

    expect(labelBottom, lessThanOrEqualTo(inputTop));
  });

  testWidgets('theme mode stays in draft until saved', (tester) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.scrollUntilVisible(
      find.text('主题模式'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();

    expect(controller.savedSettings.value.themeMode, AppThemeMode.light);
    expect(controller.draftSettings.value.themeMode, AppThemeMode.dark);
    expect(controller.isDirty.value, isTrue);
  });

  testWidgets('category rows follow dark theme palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SettingsCategoryContent(
            categories: const [
              CategoryConfig(
                key: 'cat_1',
                targetChatId: -1001,
                targetChatTitle: '星空',
              ),
            ],
            savedCategories: const [
              CategoryConfig(
                key: 'cat_1',
                targetChatId: -1001,
                targetChatTitle: '星空',
              ),
            ],
            chats: const [SelectableChat(id: -1001, title: '星空')],
            onAdd: () async {},
            onChanged: (_, chat) {},
            onRemove: (_) async {},
          ),
        ),
      ),
    );

    final row = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(SettingsCategoryContent),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    final decoration = row.decoration as BoxDecoration;
    final border = decoration.border! as Border;

    expect(decoration.color, const Color(0xFF2D3136));
    expect(border.top.color, const Color(0xFF3B4148));
  });
}

Future<SettingsCoordinator> _pumpSettingsPage(
  WidgetTester tester, {
  required List<SelectableChat> chats,
  AppSettings? initialSettings,
  _SettingsPageFakeGateway? gateway,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final resolvedGateway = gateway ?? _SettingsPageFakeGateway(chats);
  final controller = SettingsCoordinator(
    SettingsRepository(prefs),
    resolvedGateway,
    auth: resolvedGateway,
  );
  controller.onInit();
  if (initialSettings != null) {
    controller.savedSettings.value = initialSettings;
    controller.draftSettings.value = initialSettings;
    controller.isDirty.value = false;
  }
  Get.put<SettingsCoordinator>(controller);

  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: SettingsPage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _SettingsPageFakeGateway implements AuthGateway, SessionQueryGateway {
  _SettingsPageFakeGateway(this._chats);

  final List<SelectableChat> _chats;
  Object? restartError;

  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {
    if (restartError != null) {
      throw restartError!;
    }
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<List<SelectableChat>> listSelectableChats() async => _chats;
}
