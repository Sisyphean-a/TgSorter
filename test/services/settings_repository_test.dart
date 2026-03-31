import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    test('load uses latestFirst by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.fetchDirection, MessageFetchDirection.latestFirst);
    });

    test('load parses oldestFirst from storage', () async {
      SharedPreferences.setMockInitialValues({
        'message_fetch_direction': 'oldest_first',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.fetchDirection, MessageFetchDirection.oldestFirst);
    });

    test('save persists fetch direction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().updateFetchDirection(
        MessageFetchDirection.oldestFirst,
      );

      await repo.save(settings);

      expect(prefs.getString('message_fetch_direction'), 'oldest_first');
    });

    test('load uses batch defaults when storage is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.batchSize, 5);
      expect(settings.throttleMs, 1200);
    });

    test('save persists batch settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().updateBatchOptions(
        batchSize: 12,
        throttleMs: 1800,
      );

      await repo.save(settings);

      expect(prefs.getInt('pipeline_batch_size'), 12);
      expect(prefs.getInt('pipeline_throttle_ms'), 1800);
    });

    test('save persists shortcut bindings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().updateShortcutBinding(
        ShortcutAction.skipCurrent,
        const ShortcutBinding(
          action: ShortcutAction.skipCurrent,
          trigger: ShortcutTrigger.keyB,
          ctrl: true,
        ),
      );

      await repo.save(settings);

      expect(prefs.getString('shortcut_skipCurrent'), 'ctrl+keyB');
    });

    test('load falls back to defaults for invalid shortcut value', () async {
      SharedPreferences.setMockInitialValues({'shortcut_skipCurrent': 'x+y'});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(
        settings.shortcutBindings[ShortcutAction.skipCurrent]?.trigger,
        ShortcutTrigger.keyS,
      );
      expect(
        settings.shortcutBindings[ShortcutAction.skipCurrent]?.ctrl,
        isFalse,
      );
    });
  });
}
