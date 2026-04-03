import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_controller_legacy.dart';
import 'package:tgsorter/app/features/settings/application/settings_controller_legacy.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void registerPipelineModule() {
  Get.put(
    PipelineController(
      service: Get.find<TelegramGateway>(),
      settingsProvider: Get.find<SettingsController>(),
      journalRepository: Get.find<OperationJournalRepository>(),
      errorController: Get.find<AppErrorController>(),
    ),
    permanent: true,
  );
}
