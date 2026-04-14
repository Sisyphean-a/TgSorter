import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/login_alerts/application/login_alert_workbench_controller.dart';
import 'package:tgsorter/app/features/login_alerts/presentation/login_alert_workbench_page.dart';
import 'package:tgsorter/app/services/login_alert_repository.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets('workbench shows code and new login details', (tester) async {
    Get.testMode = true;
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = LoginAlertRepository(prefs);
    await repository.save(const <TelegramLoginAlert>[
      TelegramLoginAlert(
        kind: TelegramLoginAlertKind.code,
        status: TelegramLoginAlertStatus.used,
        messageId: 18,
        chatId: 777000,
        receivedAtMs: 1700000000000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'Login code: 404237',
        code: '404237',
        consumedAtMs: 1700000005000,
      ),
      TelegramLoginAlert(
        kind: TelegramLoginAlertKind.newLogin,
        status: TelegramLoginAlertStatus.info,
        messageId: 19,
        chatId: 777000,
        receivedAtMs: 1700000005000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'New login.\nDevice: Telegram Desktop\nLocation: Hangzhou, China',
        deviceSummary: 'Telegram Desktop',
        location: 'Hangzhou, China',
      ),
    ]);
    final controller = LoginAlertWorkbenchController(
      updates: const Stream<Map<String, dynamic>>.empty(),
      repository: repository,
      nowMs: () => 1700000000000,
    )..onInit();
    addTearDown(controller.onClose);
    await tester.pump();

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: LoginAlertWorkbenchPage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('接码'), findsOneWidget);
    expect(find.text('404237'), findsOneWidget);
    expect(find.text('Telegram Desktop'), findsOneWidget);
    expect(find.text('Hangzhou, China'), findsOneWidget);
    expect(find.text('已使用'), findsOneWidget);
  });
}
