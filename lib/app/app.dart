import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/core/routing/navigator_auth_navigation_adapter.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/shared/presentation/widgets/tdlib_exit_guard.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/theme/app_theme_scope.dart';

class TgSorterApp extends StatelessWidget {
  const TgSorterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsCoordinator>();
    final navigation = Get.find<NavigatorAuthNavigationAdapter>();
    return Obx(
      () => TdlibExitGuard(
        child: MaterialApp(
          navigatorKey: navigation.key,
          navigatorObservers: [navigation],
          title: 'TgSorter',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: AppThemeScope.resolve(
            settings.savedSettings.value.themeMode,
          ),
          initialRoute: navigation.initialRoute,
          routes: buildAppRoutes(),
        ),
      ),
    );
  }
}
