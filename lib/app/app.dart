import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/theme/app_theme_scope.dart';

class TgSorterApp extends StatelessWidget {
  const TgSorterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<SettingsCoordinator>();
    return Obx(
      () => GetMaterialApp(
        title: 'TgSorter',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: AppThemeScope.resolve(
          settings.savedSettings.value.themeMode,
        ),
        initialRoute: AppRoutes.auth,
        getPages: buildAppPages(),
      ),
    );
  }
}
