import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/default_workbench.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    test('load uses latestFirst by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.fetchDirection, MessageFetchDirection.latestFirst);
      expect(settings.forwardAsCopy, isFalse);
      expect(settings.categories, isEmpty);
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

    test('load uses light theme mode by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.themeMode, AppThemeMode.light);
    });

    test('save persists theme mode and load restores it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().copyWith(
        themeMode: AppThemeMode.system,
      );

      await repo.save(settings);

      expect(prefs.getString('app_theme_mode'), 'system');
      expect(repo.load().themeMode, AppThemeMode.system);
    });

    test('save persists default workbench and load restores it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().copyWith(
        defaultWorkbench: AppDefaultWorkbench.tagging,
      );

      await repo.save(settings);

      expect(prefs.getString('app_default_workbench'), 'tagging');
      expect(repo.load().defaultWorkbench, AppDefaultWorkbench.tagging);
    });

    test('load uses null sourceChatId by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.sourceChatId, isNull);
    });

    test('load uses null tagSourceChatId by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.tagSourceChatId, isNull);
    });

    test('save persists sourceChatId', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().updateSourceChatId(123456789);

      await repo.save(settings);

      expect(prefs.getString('source_chat_id'), '123456789');
    });

    test('save persists tagSourceChatId', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().copyWith(tagSourceChatId: -1001);

      await repo.save(settings);

      expect(prefs.getString('tag_source_chat_id'), '-1001');
      expect(repo.load().tagSourceChatId, -1001);
    });

    test('save persists forwardAsCopy option', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().updateForwardAsCopy(true);

      await repo.save(settings);

      expect(prefs.getBool('forward_as_copy'), isTrue);
      expect(repo.load().forwardAsCopy, isTrue);
    });

    test('save persists dynamic categories and load restores them', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults()
          .addCategory(
            const CategoryConfig(
              key: 'cat_1',
              targetChatId: -1001,
              targetChatTitle: '频道一',
            ),
          )
          .addCategory(
            const CategoryConfig(
              key: 'cat_2',
              targetChatId: -1002,
              targetChatTitle: '群组二',
            ),
          );

      await repo.save(settings);
      final loaded = repo.load();

      expect(prefs.getStringList('category_keys'), ['cat_1', 'cat_2']);
      expect(loaded.categories.length, 2);
      expect(loaded.categories.first.targetChatTitle, '频道一');
      expect(loaded.categories.last.targetChatId, -1002);
    });

    test('save persists default tag group and load restores it', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().copyWith(
        tagGroups: [
          TagGroupConfig.fromRaw(
            key: TagGroupConfig.defaultGroupKey,
            title: TagGroupConfig.defaultGroupTitle,
            tags: const ['摄影', '#风景'],
          ),
        ],
      );

      await repo.save(settings);
      final loaded = repo.load();

      expect(prefs.getStringList('tag_default_group_tags'), ['摄影', '风景']);
      expect(loaded.tagGroups.single.tags.map((item) => item.name), [
        '摄影',
        '风景',
      ]);
    });

    test('save removes stale category keys', () async {
      SharedPreferences.setMockInitialValues({
        'category_keys': ['old_1'],
        'category_chat_id_old_1': -1009,
        'category_chat_title_old_1': '旧分类',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      await repo.save(AppSettings.defaults());

      expect(prefs.getStringList('category_keys'), isEmpty);
      expect(prefs.getInt('category_chat_id_old_1'), isNull);
      expect(prefs.getString('category_chat_title_old_1'), isNull);
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

    test('save persists proxy settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);
      final settings = AppSettings.defaults().updateProxySettings(
        const ProxySettings(
          server: '127.0.0.1',
          port: 7897,
          username: '',
          password: '',
        ),
      );

      await repo.save(settings);

      expect(prefs.getString('tdlib_proxy_server'), '127.0.0.1');
      expect(prefs.getInt('tdlib_proxy_port'), 7897);
    });

    test('load parses proxy settings from storage', () async {
      SharedPreferences.setMockInitialValues({
        'tdlib_proxy_server': '127.0.0.1',
        'tdlib_proxy_port': 7897,
        'tdlib_proxy_username': 'user',
        'tdlib_proxy_password': 'pass',
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = SettingsRepository(prefs);

      final settings = repo.load();

      expect(settings.proxy.server, '127.0.0.1');
      expect(settings.proxy.port, 7897);
      expect(settings.proxy.username, 'user');
      expect(settings.proxy.password, 'pass');
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
