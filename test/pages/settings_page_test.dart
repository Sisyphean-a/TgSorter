import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/application/settings_page_draft_session.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_app_bar.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_screen.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
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
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('关于账号与会话'), findsOneWidget);
    expect(find.text('恢复已略过数据'), findsOneWidget);

    expect(find.text('转发来源会话'), findsNothing);
    expect(find.text('标签来源会话'), findsNothing);
    expect(find.text('代理服务器'), findsNothing);
    expect(find.text('默认标签组'), findsNothing);
    expect(find.text('保存更改'), findsNothing);
    expect(find.text('放弃更改'), findsNothing);
    expect(find.byType(StatusBadge), findsNothing);
    expect(find.byType(SettingsNavigationTile), findsNWidgets(8));
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

    await _setDialogField(
      tester,
      tileTitle: '代理服务器',
      fieldLabel: '代理服务器',
      value: '127.0.0.1',
    );

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
    await _selectChoice(
      tester,
      tileTitle: '消息拉取方向',
      optionLabel: '最旧优先',
    );

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

    expect(find.text('未设置'), findsAtLeastNWidgets(1));
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

    await _selectChoice(
      tester,
      tileTitle: '消息拉取方向',
      optionLabel: '最旧优先',
    );
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

    await tester.tap(find.text('批处理条数 N'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '批处理条数 N'), '0');
    await tester.pumpAndSettle();

    expect(find.text('请输入大于等于 1 的整数'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('非法代理端口会显示错误并阻止保存', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('代理端口'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '代理端口'), 'abc');
    await tester.pumpAndSettle();

    expect(find.text('请输入大于 0 的端口'), findsOneWidget);

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
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

    await _setDialogField(
      tester,
      tileTitle: '代理服务器',
      fieldLabel: '代理服务器',
      value: '127.0.0.1',
    );
    await _setDialogField(
      tester,
      tileTitle: '代理端口',
      fieldLabel: '代理端口',
      value: '7890',
    );

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

    await _selectChoice(
      tester,
      tileTitle: '首页默认工作台',
      optionLabel: '标签工作台',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(
      controller.savedSettings.value.defaultWorkbench,
      AppDefaultWorkbench.tagging,
    );
  });

  testWidgets('下载页承载工作台开关与同步策略', (tester) async {
    final controller = await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();

    expect(find.text('下载工作台'), findsAtLeastNWidgets(1));
    expect(find.text('启用下载工作台'), findsOneWidget);
    expect(find.text('已存在文件策略'), findsOneWidget);
    expect(find.text('命名冲突处理'), findsOneWidget);
    expect(find.text('目录映射规则'), findsOneWidget);
    expect(find.text('下载范围'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await _selectChoice(
      tester,
      tileTitle: '目录映射规则',
      optionLabel: '平铺到目标目录',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(controller.savedSettings.value.downloadWorkbenchEnabled, isTrue);
    expect(controller.savedSettings.value.downloadDirectoryMode.name, 'flat');
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

    await tester.scrollUntilVisible(find.text('关于账号与会话'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关于账号与会话'));
    await tester.pumpAndSettle();

    expect(find.text('账号与会话'), findsAtLeastNWidgets(1));
    expect(find.text('退出登录'), findsAtLeastNWidgets(1));
    expect(find.text('刷新会话'), findsOneWidget);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();

    expect(find.text('确认退出登录'), findsOneWidget);
    expect(find.textContaining('退出后会返回登录页'), findsAtLeastNWidgets(1));

    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();
    expect(gateway.logoutCalls, 0);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认退出'));
    await tester.pumpAndSettle();

    expect(gateway.logoutCalls, 1);
  });

  testWidgets('恢复已略过数据页支持按全部按工作流按来源恢复', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [
        SelectableChat(id: 8888, title: '转发来源'),
        SelectableChat(id: 9999, title: '标签来源'),
      ],
      skippedRecords: const <SkippedMessageRecord>[
        SkippedMessageRecord(
          id: 'forwarding:8888:1',
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
          primaryMessageId: 1,
          messageIds: <int>[1],
          createdAtMs: 1,
        ),
        SkippedMessageRecord(
          id: 'tagging:9999:2',
          workflow: SkippedMessageWorkflow.tagging,
          sourceChatId: 9999,
          primaryMessageId: 2,
          messageIds: <int>[2],
          createdAtMs: 2,
        ),
      ],
    );

    await tester.tap(find.text('恢复已略过数据'));
    await tester.pumpAndSettle();

    expect(find.text('全部恢复'), findsOneWidget);
    expect(find.text('按工作流恢复'), findsOneWidget);
    expect(find.text('按来源恢复'), findsOneWidget);
    expect(find.text('恢复转发'), findsOneWidget);
    expect(find.text('恢复标签'), findsOneWidget);
    expect(find.text('转发来源'), findsOneWidget);
    expect(find.text('标签来源'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '恢复转发'));
    await tester.pumpAndSettle();

    expect(find.text('已恢复 1 条略过记录'), findsOneWidget);
    expect(find.text('转发来源'), findsNothing);
    expect(find.text('标签来源'), findsOneWidget);
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

  testWidgets('转发页主列表不再使用下拉框和常驻输入框', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('转发'));
    await tester.pumpAndSettle();

    expect(_dropdownFormFields(), findsNothing);
    expect(find.widgetWithText(TextField, '批处理条数 N'), findsNothing);
    expect(find.widgetWithText(TextField, '节流毫秒'), findsNothing);
  });

  testWidgets('连接页点击摘要行后才弹出代理服务器编辑器', (tester) async {
    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    await tester.tap(find.text('连接与网络'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('代理服务器'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '代理服务器'), findsOneWidget);
  });

  testWidgets('桌面端设置页使用窄列容器而不是铺满内容区', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpSettingsPage(
      tester,
      chats: const [SelectableChat(id: -1001, title: '频道一')],
    );

    expect(find.byKey(const ValueKey('settings-desktop-column')), findsOneWidget);
  });
}

Future<SettingsCoordinator> _pumpSettingsPage(
  WidgetTester tester, {
  required List<SelectableChat> chats,
  AppSettings? initialSettings,
  _SettingsPageFakeGateway? gateway,
  List<SkippedMessageRecord> skippedRecords = const <SkippedMessageRecord>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (skippedRecords.isNotEmpty)
      'skipped_messages_json': jsonEncode(
        skippedRecords.map((item) => item.toJson()).toList(growable: false),
      ),
  });
  final prefs = await SharedPreferences.getInstance();
  final repository = SettingsRepository(prefs);
  if (initialSettings != null) {
    await repository.save(initialSettings);
  }
  final resolvedGateway = gateway ?? _SettingsPageFakeGateway(chats);
  final controller = SettingsCoordinator(
    repository,
    resolvedGateway,
    auth: resolvedGateway,
    skippedMessageRepository: SkippedMessageRepository(prefs),
  );
  final navigation = SettingsNavigationController();
  final draftSession = SettingsPageDraftSession();
  controller.onInit();
  Get.put<SettingsCoordinator>(controller);

  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: _SettingsTestShell(
        controller: controller,
        navigation: navigation,
        draftSession: draftSession,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

class _SettingsTestShell extends StatelessWidget {
  const _SettingsTestShell({
    required this.controller,
    required this.navigation,
    required this.draftSession,
  });

  final SettingsCoordinator controller;
  final SettingsNavigationController navigation;
  final SettingsPageDraftSession draftSession;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: SettingsAppBar(
        draftSession: draftSession,
        isSaving: controller.isSaving,
        navigation: navigation,
        onSave: () => _handleSave(context),
      ),
      body: SettingsScreen(
        controller: controller,
        navigation: navigation,
        draftSession: draftSession,
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (controller.isSaving.value) {
      return;
    }
    if (draftSession.hasValidationErrors.value) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('请先修正输入错误')));
      return;
    }
    try {
      final result = await controller.savePageDraft(
        draftSession.draftSettings.value,
      );
      draftSession.markSaved(controller.savedSettings.value);
      if (!context.mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(_saveMessage(result))));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  String _saveMessage(SettingsSaveResult result) {
    switch (result) {
      case SettingsSaveResult.saved:
      case SettingsSaveResult.savedAndRestarted:
        return '设置已保存';
      case SettingsSaveResult.savedNeedsRestartAttention:
        return '设置已保存，但重启失败，请稍后手动重试。';
    }
  }
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

Finder _dropdownFormFields() {
  return find.byWidgetPredicate((widget) => widget is DropdownButtonFormField);
}

Future<void> _selectChoice(
  WidgetTester tester, {
  required String tileTitle,
  required String optionLabel,
}) async {
  await tester.tap(find.text(tileTitle).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionLabel).last);
  await tester.pumpAndSettle();
}

Future<void> _setDialogField(
  WidgetTester tester, {
  required String tileTitle,
  required String fieldLabel,
  required String value,
}) async {
  await tester.tap(find.text(tileTitle).first);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, fieldLabel), value);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, '保存'));
  await tester.pumpAndSettle();
}
