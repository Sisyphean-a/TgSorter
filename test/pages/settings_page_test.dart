import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  testWidgets('首页只显示目录行而不直接显示复杂编辑器', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: -1001, title: '频道一'),
        SelectableChat(id: -1002, title: '频道二'),
      ],
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('工作流'), findsOneWidget);
    expect(find.text('应用'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('连接与网络'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('快捷键'), findsOneWidget);

    expect(find.text('转发来源会话'), findsNothing);
    expect(find.text('标签来源会话'), findsNothing);
    expect(find.text('代理服务器'), findsNothing);
    expect(find.text('默认标签组'), findsNothing);
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('放弃更改'), findsNothing);
    expect(find.byType(StatusBadge), findsNothing);
    expect(find.byType(SettingsNavigationTile), findsNWidgets(5));
  });

  testWidgets('点击目录行后进入对应二级页并显示返回箭头', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsNothing);
    expect(find.text('连接与网络'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.text('代理服务器'), findsOneWidget);
    expect(find.text('主题模式'), findsNothing);
    expect(find.text('转发'), findsNothing);
  });

  testWidgets('二级页 dirty 后显示保存动作且不再显示状态徽标', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    expect(find.text('保存'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, '代理服务器'), '127.0.0.1');
    await tester.pumpAndSettle();

    expect(find.text('保存'), findsOneWidget);
    expect(find.byType(StatusBadge), findsNothing);
  });

  testWidgets('二级页使用页面本地草稿并在返回时确认放弃', (tester) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('转发'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最新优先'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最旧优先').last);
    await tester.pumpAndSettle();

    expect(
      controller.savedSettings.value.fetchDirection,
      MessageFetchDirection.latestFirst,
    );
    expect(find.text('保存'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('继续编辑'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '放弃更改'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '放弃更改'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('保存'), findsNothing);

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    final serverField = tester.widget<TextField>(
      find.widgetWithText(TextField, '代理服务器'),
    );
    expect(serverField.controller?.text ?? '', isEmpty);
    expect(
      controller.savedSettings.value.fetchDirection,
      MessageFetchDirection.latestFirst,
    );
  });

  testWidgets('转发页展示完整设置项并在保存后提交草稿', (tester) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: -1001, title: '频道一'),
        SelectableChat(id: -1002, title: '频道二'),
      ],
    );

    await tester.tap(find.text('转发'));
    await tester.pumpAndSettle();

    expect(find.text('转发规则'), findsOneWidget);
    expect(find.text('分类目标'), findsOneWidget);
    expect(find.text('转发来源会话'), findsOneWidget);
    expect(find.text('消息拉取方向'), findsOneWidget);
    expect(find.text('无引用转发'), findsOneWidget);
    expect(find.text('批处理条数 N'), findsOneWidget);
    expect(find.text('节流毫秒'), findsOneWidget);
    expect(find.text('预加载后续预览'), findsOneWidget);
    expect(find.text('新增分类'), findsOneWidget);

    await tester.tap(find.text('最新优先'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最旧优先').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      controller.savedSettings.value.fetchDirection,
      MessageFetchDirection.oldestFirst,
    );
    expect(find.text('保存'), findsNothing);
  });

  testWidgets('其余四个详情页都在两层结构内展示各自字段', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('标签来源'), findsOneWidget);
    expect(find.text('默认标签组'), findsOneWidget);
    expect(find.text('标签来源会话'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();
    expect(find.text('代理设置'), findsOneWidget);
    expect(find.text('会话列表'), findsOneWidget);
    expect(find.text('代理服务器'), findsOneWidget);
    expect(find.text('刷新会话'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(find.text('外观偏好'), findsOneWidget);
    expect(find.text('主题模式'), findsAtLeastNWidgets(1));
    expect(find.text('代理服务器'), findsNothing);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('快捷键'));
    await tester.pumpAndSettle();
    expect(find.text('快捷键绑定'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    expect(find.text('主题模式'), findsNothing);
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

  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => _chats;

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
