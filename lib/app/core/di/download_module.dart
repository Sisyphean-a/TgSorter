import 'package:get/get.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';

void registerDownloadModule() {
  final controller = DownloadWorkbenchController(
    sessions: Get.find<SessionQueryGateway>(),
    settings: Get.find<PipelineSettingsReader>(),
    sync: Get.find<DownloadSyncPort>(),
  );
  Get.put(controller, permanent: true);
}
