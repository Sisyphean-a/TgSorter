import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

void main() {
  test(
    'saveDraft persists draft, commits it, and reports restart requirement',
    () async {
      final repository = _FakeSettingsRepository();
      final service = SettingsPersistenceService(repository);
      final draft = SettingsDraftCoordinator(AppSettings.defaults());

      draft.update(
        draft.draft.value.copyWith(
          proxy: const ProxySettings(
            server: '127.0.0.1',
            port: 7890,
            username: '',
            password: '',
          ),
        ),
      );

      final shouldRestart = await service.saveDraft(draft);

      expect(shouldRestart, isTrue);
      expect(repository.saveCalls, 1);
      expect(draft.isDirty.value, isFalse);
      expect(draft.saved.value.proxy.server, '127.0.0.1');
    },
  );

  test('load returns repository settings', () {
    final repository = _FakeSettingsRepository()
      ..current = const AppSettings(
        categories: [
          CategoryConfig(
            key: 'cat-1',
            targetChatId: -1001,
            targetChatTitle: '频道一',
          ),
        ],
        sourceChatId: null,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 5,
        throttleMs: 1200,
        proxy: ProxySettings.empty,
      );
    final service = SettingsPersistenceService(repository);

    expect(service.load(), repository.current);
  });
}

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings current = AppSettings.defaults();
  int saveCalls = 0;

  @override
  AppSettings load() => current;

  @override
  Future<void> save(AppSettings settings) async {
    saveCalls++;
    current = settings;
  }
}
