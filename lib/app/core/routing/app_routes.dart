import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page.dart';

abstract final class AppRoutes {
  static const auth = '/auth';
  static const pipeline = '/pipeline';
  static const settings = '/settings';
}

List<GetPage<dynamic>> buildAppPages() {
  return [
    GetPage(
      name: AppRoutes.auth,
      page: () => AuthPage(
        auth: Get.find<AuthCoordinator>(),
        errors: Get.find<AppErrorController>(),
        settings: Get.find<SettingsCoordinator>(),
      ),
    ),
    GetPage(
      name: AppRoutes.pipeline,
      page: () => PipelinePage(
        pipeline: Get.find<PipelineCoordinator>(),
        settings: Get.find<SettingsCoordinator>(),
        errors: Get.find<AppErrorController>(),
      ),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => SettingsPage(
        controller: Get.find<SettingsCoordinator>(),
        pipeline: Get.isRegistered<PipelineCoordinator>()
            ? Get.find<PipelineCoordinator>()
            : null,
      ),
    ),
  ];
}
