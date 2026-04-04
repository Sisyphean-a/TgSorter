import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

void main() {
  test('save persists provided settings', () async {
    final repository = _FakeSettingsRepository();
    final service = SettingsPersistenceService(repository);
    final next = AppSettings.defaults().copyWith(
      proxy: const ProxySettings(
        server: '127.0.0.1',
        port: 7890,
        username: '',
        password: '',
      ),
    );

    expect(service.save(next), completion(isNull));
    await pumpEventQueue();

    expect(repository.saveCalls, 1);
    expect(repository.current.proxy.server, '127.0.0.1');
  });

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
