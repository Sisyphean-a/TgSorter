import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/services/login_alert_repository.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';

void main() {
  group('LoginAlertRepository', () {
    test('persists and reloads alerts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = LoginAlertRepository(prefs);
      const alert = TelegramLoginAlert(
        kind: TelegramLoginAlertKind.code,
        status: TelegramLoginAlertStatus.used,
        messageId: 18,
        chatId: 777000,
        receivedAtMs: 1700000000000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'Login code: 404237',
        code: '404237',
        consumedAtMs: 1700000010000,
      );

      await repository.save(const <TelegramLoginAlert>[alert]);
      final restored = await repository.load();

      expect(restored, hasLength(1));
      expect(restored.single.messageId, 18);
      expect(restored.single.code, '404237');
      expect(restored.single.status, TelegramLoginAlertStatus.used);
      expect(restored.single.consumedAtMs, 1700000010000);
    });

    test('clear removes persisted alerts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = LoginAlertRepository(prefs);
      const alert = TelegramLoginAlert(
        kind: TelegramLoginAlertKind.code,
        status: TelegramLoginAlertStatus.active,
        messageId: 18,
        chatId: 777000,
        receivedAtMs: 1700000000000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'Login code: 404237',
        code: '404237',
      );

      await repository.save(const <TelegramLoginAlert>[alert]);
      await repository.clear();

      expect(await repository.load(), isEmpty);
    });
  });
}
