import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class ShortcutSettingsService {
  AppSettings updateShortcut({
    required AppSettings current,
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    _assertNoConflict(
      current.shortcutBindings,
      action: action,
      trigger: trigger,
      ctrl: ctrl,
    );
    return current.updateShortcutBinding(
      action,
      ShortcutBinding(action: action, trigger: trigger, ctrl: ctrl),
    );
  }

  AppSettings resetDefaults(AppSettings current) {
    return current.copyWith(
      shortcutBindings: AppSettings.defaultShortcutBindings,
    );
  }

  void _assertNoConflict(
    Map<ShortcutAction, ShortcutBinding> bindings, {
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    for (final entry in bindings.entries) {
      if (entry.key == action) {
        continue;
      }
      final binding = entry.value;
      if (binding.trigger == trigger && binding.ctrl == ctrl) {
        throw StateError('快捷键冲突：${entry.key.name} 已使用该组合');
      }
    }
  }
}
