import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class CommonSettings {
  const CommonSettings({required this.proxy, required this.shortcutBindings});

  final ProxySettings proxy;
  final Map<ShortcutAction, ShortcutBinding> shortcutBindings;
}
