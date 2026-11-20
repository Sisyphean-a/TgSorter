import 'package:flutter/widgets.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';

class NavigatorAuthNavigationAdapter extends NavigatorObserver
    implements AuthNavigationPort {
  final key = GlobalKey<NavigatorState>();
  String _route = AppRoutes.auth;

  // 启动时认证状态可能先于 Navigator 就绪，记录目标供首帧使用。
  String get initialRoute => _route;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    final name = topRoute.settings.name;
    if (name == AppRoutes.auth || name == AppRoutes.app) {
      _route = name!;
    }
  }

  @override
  void goToApp() {
    if (_route == AppRoutes.app) return;
    _route = AppRoutes.app;
    key.currentState?.pushReplacementNamed<void, void>(AppRoutes.app);
  }

  @override
  void goToAuth() {
    if (_route == AppRoutes.auth) return;
    _route = AppRoutes.auth;
    key.currentState?.pushNamedAndRemoveUntil<void>(
      AppRoutes.auth,
      (_) => false,
    );
  }
}
