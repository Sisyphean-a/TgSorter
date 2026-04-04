import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/shared/presentation/widgets/sticky_action_bar.dart';

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
    expect(find.text('最近操作'), findsOneWidget);
    expect(find.text('保存更改'), findsOneWidget);
    expect(find.text('放弃更改'), findsOneWidget);
    expect(find.text('分类设置'), findsOneWidget);
    expect(find.byType(StickyActionBar), findsOneWidget);
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

  testWidgets('settings page uses compact header on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    expect(find.text('分类设置'), findsOneWidget);
    expect(find.text('统一管理分类规则、连接配置和工具项'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category rows use single-line compact actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: -1001, title: '星空'),
        SelectableChat(id: -1002, title: 'mi_ASMR'),
      ],
      initialSettings: const AppSettings(
        categories: [
          CategoryConfig(
            key: 'cat_1',
            targetChatId: -1001,
            targetChatTitle: '星空',
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

    await tester.pumpAndSettle();
    expect(find.text('删除'), findsNothing);
    expect(find.text('目标会话'), findsNothing);
    expect(find.text('星空'), findsNothing);
    expect(tester.takeException(), isNull);
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
    GetMaterialApp(home: SettingsPage(controller: controller)),
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
