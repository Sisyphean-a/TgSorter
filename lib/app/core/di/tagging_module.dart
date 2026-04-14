import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_registry.dart';
import 'package:tgsorter/app/features/tagging/application/tagging_coordinator.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

void registerTaggingModule() {
  final coordinator = TaggingCoordinator(
    authStateGateway: Get.find<AuthStateGateway>(),
    connectionStateGateway: Get.find<ConnectionStateGateway>(),
    messageReadGateway: Get.find<MessageReadGateway>(),
    mediaGateway: Get.find<MediaGateway>(),
    taggingGateway: Get.find<TaggingGateway>(),
    settingsReader: Get.find<PipelineSettingsReader>(),
    errorController: Get.find<AppErrorController>(),
    skippedMessageRepository: Get.find<SkippedMessageRepository>(),
  );
  Get.put(coordinator, permanent: true);
  Get.find<SkippedMessageRestoreRegistry>().register(coordinator);
}
