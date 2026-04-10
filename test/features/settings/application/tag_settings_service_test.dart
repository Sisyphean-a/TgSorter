import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/tag_settings_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';

void main() {
  group('TagSettingsService', () {
    test('updates tag source chat', () {
      final service = TagSettingsService();

      final updated = service.updateTagSourceChat(
        current: AppSettings.defaults(),
        chatId: -1001,
      );

      expect(updated.tagSourceChatId, -1001);
    });

    test('adds normalized tag to default group', () {
      final service = TagSettingsService();

      final updated = service.addDefaultTag(
        current: AppSettings.defaults(),
        rawName: '#摄影',
      );

      expect(updated.tagGroups.single.tags.single.name, '摄影');
    });

    test('removes tag from default group', () {
      final service = TagSettingsService();
      final current = service.addDefaultTag(
        current: AppSettings.defaults(),
        rawName: '摄影',
      );

      final updated = service.removeDefaultTag(
        current: current,
        rawName: '#摄影',
      );

      expect(updated.tagGroups.single.tags, isEmpty);
    });

    test('rejects duplicate tag in default group', () {
      final service = TagSettingsService();
      final current = service.addDefaultTag(
        current: AppSettings.defaults(),
        rawName: '摄影',
      );

      expect(
        () => service.addDefaultTag(current: current, rawName: '#摄影'),
        throwsStateError,
      );
    });
  });
}
