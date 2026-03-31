import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
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
  });
}
