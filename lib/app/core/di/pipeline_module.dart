import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void registerPipelineModule() {
  Get.put(
    PipelineCoordinator(
      service: Get.find<TelegramGateway>(),
      settingsReader: Get.find<SettingsCoordinator>(),
      journalRepository: Get.find<OperationJournalRepository>(),
      errorController: Get.find<AppErrorController>(),
    ),
    permanent: true,
  );
}
