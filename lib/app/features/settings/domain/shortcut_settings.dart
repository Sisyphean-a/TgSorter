import 'package:tgsorter/app/models/shortcut_binding.dart';

class ShortcutSettings {
  const ShortcutSettings({required this.bindings});

  final Map<ShortcutAction, ShortcutBinding> bindings;
}
