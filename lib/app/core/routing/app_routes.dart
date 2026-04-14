import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/presentation/auth_page.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/shell/presentation/main_shell_page.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';

abstract final class AppRoutes {
  static const auth = '/auth';
  static const app = '/app';
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
      name: AppRoutes.app,
      page: () => MainShellPage(
        pipeline: Get.find<PipelineCoordinator>(),
        tagging: Get.find<TaggingCoordinator>(),
        downloads: Get.find<DownloadWorkbenchController>(),
        pipelineSettings: Get.find<PipelineSettingsReader>(),
        errors: Get.find<AppErrorController>(),
        settings: Get.find<SettingsCoordinator>(),
        pipelineLogs: Get.isRegistered<PipelineLogsPort>()
            ? Get.find<PipelineLogsPort>()
            : null,
      ),
    ),
  ];
}
