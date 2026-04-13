import 'package:get/get.dart';

enum SettingsRoute {
  home,
  forwarding,
  tagging,
  connection,
  appearance,
  shortcuts,
}

extension SettingsRoutePresentation on SettingsRoute {
  String get title {
    switch (this) {
      case SettingsRoute.home:
        return '设置';
      case SettingsRoute.forwarding:
        return '转发';
      case SettingsRoute.tagging:
        return '标签';
      case SettingsRoute.connection:
        return '连接与网络';
      case SettingsRoute.appearance:
        return '外观';
      case SettingsRoute.shortcuts:
        return '快捷键';
    }
  }
}

class SettingsNavigationController {
  final currentRoute = SettingsRoute.home.obs;
  final canPop = false.obs;

  String get currentTitle => currentRoute.value.title;

  void goTo(SettingsRoute route) {
    currentRoute.value = route;
    canPop.value = route != SettingsRoute.home;
  }

  void backToHome() {
    goTo(SettingsRoute.home);
  }
}
