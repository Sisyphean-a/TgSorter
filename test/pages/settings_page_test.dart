import 'dart:async';

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
import 'package:tgsorter/app/models/default_workbench.dart';
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
    expect(find.text('账号'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
    expect(find.text('转发'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('连接与网络'), findsOneWidget);
    expect(find.text('快捷键'), findsOneWidget);
    expect(find.text('关于账号与会话'), findsOneWidget);

    expect(find.text('转发来源会话'), findsNothing);
    expect(find.text('标签来源会话'), findsNothing);
    expect(find.text('代理服务器'), findsNothing);
    expect(find.text('默认标签组'), findsNothing);
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('放弃更改'), findsNothing);
    expect(find.byType(StatusBadge), findsNothing);
    expect(find.byType(SettingsNavigationTile), findsNWidgets(6));
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

    await tester.enterText(
      find.widgetWithText(TextField, '代理服务器'),
      '127.0.0.1',
    );
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

  testWidgets('非法批处理输入会显示错误并阻止保存', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('转发'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '批处理条数 N'), '0');
    await tester.pumpAndSettle();

    expect(find.text('请输入大于等于 1 的整数'), findsOneWidget);

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '保存'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, '放弃更改'), findsOneWidget);
  });

  testWidgets('非法代理端口会显示错误并阻止保存', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '代理服务器'),
      '127.0.0.1',
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '代理端口'), 'abc');
    await tester.pumpAndSettle();

    expect(find.text('请输入大于 0 的端口'), findsOneWidget);

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '保存'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('保存进行中会禁用二次保存和返回', (tester) async {
    final gateway = _SettingsPageFakeGateway(const [
      SelectableChat(id: -1001, title: '频道一'),
    ])..restartCompleter = Completer<void>();
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
      gateway: gateway,
    );

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, '代理服务器'),
      '127.0.0.1',
    );
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '代理端口'), '7890');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pump();

    final saveButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '保存'),
    );
    final backButton = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .firstWhere((button) => button.tooltip == '返回');
    final detailGuards = tester.widgetList<IgnorePointer>(
      find.byType(IgnorePointer),
    );

    expect(saveButton.onPressed, isNull);
    expect(backButton.onPressed, isNull);
    expect(detailGuards.any((guard) => guard.ignoring), isTrue);

    gateway.restartCompleter!.complete();
    await tester.pumpAndSettle();

    expect(find.text('设置已保存'), findsOneWidget);
  });

  testWidgets('通用页承载默认工作台和主题设置', (tester) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();

    expect(find.text('通用偏好'), findsOneWidget);
    expect(find.text('首页默认工作台'), findsOneWidget);
    expect(find.text('主题模式'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('转发工作台'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标签工作台').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      controller.savedSettings.value.defaultWorkbench,
      AppDefaultWorkbench.tagging,
    );
  });

  testWidgets('关于账号与会话页提供显式确认的退出登录', (tester) async {
    final gateway = _SettingsPageFakeGateway(const [
      SelectableChat(id: -1001, title: '频道一'),
    ]);
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
      gateway: gateway,
    );

    await tester.tap(find.text('关于账号与会话'));
    await tester.pumpAndSettle();

    expect(find.text('账号与会话'), findsAtLeastNWidgets(1));
    expect(find.text('退出登录'), findsAtLeastNWidgets(1));
    expect(find.text('刷新会话'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('确认退出登录'), findsOneWidget);
    expect(find.textContaining('退出后会返回登录页'), findsAtLeastNWidgets(1));

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(gateway.logoutCalls, 0);

    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认退出'));
    await tester.pumpAndSettle();

    expect(gateway.logoutCalls, 1);
  });

  testWidgets('其余详情页都在两层结构内展示各自字段', (tester) async {
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
  Completer<void>? restartCompleter;
  int logoutCalls = 0;

  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => _chats;

  @override
  Future<void> restart() async {
    final completer = restartCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}
