import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/pages/auth_page.dart';
import 'package:tgsorter/app/pages/pipeline_page.dart';
import 'package:tgsorter/app/pages/settings_page.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

class TgSorterApp extends StatelessWidget {
  const TgSorterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TgSorter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: '/auth',
      getPages: [
        GetPage(
          name: '/auth',
          page: () => AuthPage(
            auth: Get.find<AuthController>(),
            errors: Get.find<AppErrorController>(),
            settings: Get.find<SettingsController>(),
          ),
        ),
        GetPage(
          name: '/pipeline',
          page: () => PipelinePage(
            pipeline: Get.find<PipelineController>(),
            settings: Get.find<SettingsController>(),
            errors: Get.find<AppErrorController>(),
          ),
        ),
        GetPage(
          name: '/settings',
          page: () => SettingsPage(
            controller: Get.find<SettingsController>(),
            pipeline: Get.isRegistered<PipelineController>()
                ? Get.find<PipelineController>()
                : null,
          ),
        ),
      ],
    );
  }
}
