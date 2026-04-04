import 'package:get/get.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_settings_port.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

void registerSettingsModule() {
  final coordinator = SettingsCoordinator(
    Get.find<SettingsRepository>(),
    Get.find<SessionQueryGateway>(),
    auth: Get.find<AuthGateway>(),
  );
  Get.put(coordinator, permanent: true);
  Get.put<AuthSettingsPort>(coordinator, permanent: true);
  Get.put<PipelineSettingsReader>(coordinator, permanent: true);
}
