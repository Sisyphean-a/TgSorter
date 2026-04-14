import 'package:get/get.dart';

enum SettingsRoute {
  home,
  common,
  downloads,
  forwarding,
  tagging,
  connection,
  shortcuts,
  skippedMessages,
  accountSession,
}

extension SettingsRoutePresentation on SettingsRoute {
  String get title {
    switch (this) {
      case SettingsRoute.home:
        return '设置';
      case SettingsRoute.common:
        return '通用';
      case SettingsRoute.downloads:
        return '下载';
      case SettingsRoute.forwarding:
        return '转发';
      case SettingsRoute.tagging:
        return '标签';
      case SettingsRoute.connection:
        return '连接与网络';
      case SettingsRoute.shortcuts:
        return '快捷键';
      case SettingsRoute.skippedMessages:
        return '恢复已略过数据';
      case SettingsRoute.accountSession:
        return '账号与会话';
    }
  }

  String get homeLabel {
    switch (this) {
      case SettingsRoute.accountSession:
        return '关于账号与会话';
      default:
        return title;
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
