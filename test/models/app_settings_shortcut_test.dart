import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/models/tag_config.dart';

void main() {
  group('AppSettings shortcut bindings', () {
    test('defaults include all required shortcut actions', () {
      final settings = AppSettings.defaults();

      expect(
        settings.shortcutBindings.keys,
        containsAll(ShortcutAction.values),
      );
      expect(
        settings.shortcutBindings[ShortcutAction.previousMessage]?.trigger,
        ShortcutTrigger.digit1,
      );
      expect(
        settings.shortcutBindings[ShortcutAction.nextMessage]?.trigger,
        ShortcutTrigger.digit2,
      );
    });

    test('updateShortcutBinding returns a new immutable settings object', () {
      final settings = AppSettings.defaults();

      final updated = settings.updateShortcutBinding(
        ShortcutAction.skipCurrent,
        const ShortcutBinding(
          action: ShortcutAction.skipCurrent,
          trigger: ShortcutTrigger.keyB,
          ctrl: false,
        ),
      );

      expect(updated, isNot(same(settings)));
      expect(
        updated.shortcutBindings[ShortcutAction.skipCurrent]?.trigger,
        ShortcutTrigger.keyB,
      );
      expect(
        settings.shortcutBindings[ShortcutAction.skipCurrent]?.trigger,
        ShortcutTrigger.keyS,
      );
    });
  });

  group('AppSettings tagging settings', () {
    test('defaults include empty tag source and default tag group', () {
      final settings = AppSettings.defaults();

      expect(settings.tagSourceChatId, isNull);
      expect(settings.tagGroups, [
        const TagGroupConfig(key: 'default', title: '默认组', tags: []),
      ]);
    });

    test('copyWith updates tagging settings and equality tracks them', () {
      final settings = AppSettings.defaults();
      final tagGroups = [
        TagGroupConfig.fromRaw(
          key: 'default',
          title: '默认组',
          tags: const ['摄影'],
        ),
      ];

      final updated = settings.copyWith(
        tagSourceChatId: -1001,
        tagGroups: tagGroups,
      );

      expect(updated.tagSourceChatId, -1001);
      expect(updated.tagGroups.single.tags.single.name, '摄影');
      expect(updated, isNot(settings));
      expect(updated.copyWith(), updated);
    });

    test('semantic sections expose forwarding tagging and common settings', () {
      final settings = AppSettings.defaults().copyWith(
        tagSourceChatId: -1001,
        tagGroups: [
          TagGroupConfig.fromRaw(
            key: 'default',
            title: '默认组',
            tags: const ['摄影'],
          ),
        ],
      );

      expect(settings.forwarding.sourceChatId, settings.sourceChatId);
      expect(settings.forwarding.categories, settings.categories);
      expect(settings.tagging.sourceChatId, -1001);
      expect(settings.tagging.defaultGroup.tags.single.name, '摄影');
      expect(settings.common.proxy, settings.proxy);
      expect(settings.common.shortcutBindings, settings.shortcutBindings);
    });
  });
}
