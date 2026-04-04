import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_page.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';

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
      ),
    ),
    GetPage(
      name: AppRoutes.pipeline,
      page: () => PipelinePage(
        pipeline: Get.find<PipelineCoordinator>(),
        settings: Get.find<PipelineSettingsReader>(),
        errors: Get.find<AppErrorController>(),
      ),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => SettingsPage(
        controller: Get.find<SettingsCoordinator>(),
        pipeline: Get.isRegistered<PipelineLogsPort>()
            ? Get.find<PipelineLogsPort>()
            : null,
      ),
    ),
  ];
}
