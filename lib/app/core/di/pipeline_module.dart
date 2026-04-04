import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';

void registerPipelineModule() {
  final coordinator = PipelineCoordinator(
    authStateGateway: Get.find<AuthStateGateway>(),
    connectionStateGateway: Get.find<ConnectionStateGateway>(),
    messageReadGateway: Get.find<MessageReadGateway>(),
    mediaGateway: Get.find<MediaGateway>(),
    classifyGateway: Get.find<ClassifyGateway>(),
    recoveryGateway: Get.find<RecoveryGateway>(),
    settingsReader: Get.find<PipelineSettingsReader>(),
    journalRepository: Get.find<OperationJournalRepository>(),
    errorController: Get.find<AppErrorController>(),
  );
  Get.put(coordinator, permanent: true);
  Get.put<PipelineLogsPort>(coordinator, permanent: true);
}
