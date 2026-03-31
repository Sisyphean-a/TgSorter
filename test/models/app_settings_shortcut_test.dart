import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

void main() {
  group('AppSettings shortcut bindings', () {
    test('defaults include all required shortcut actions', () {
      final settings = AppSettings.defaults();

      expect(
        settings.shortcutBindings.keys,
        containsAll(ShortcutAction.values),
      );
      expect(
        settings.shortcutBindings[ShortcutAction.classifyA]?.trigger,
        ShortcutTrigger.digit1,
      );
      expect(
        settings.shortcutBindings[ShortcutAction.batchA]?.ctrl,
        isTrue,
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
}
