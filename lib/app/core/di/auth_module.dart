import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';

void registerAuthModule() {
  Get.put(
    AuthCoordinator(
      Get.find<AuthGateway>(),
      Get.find<AppErrorController>(),
      Get.find<SettingsCoordinator>(),
    ),
    permanent: true,
  );
}
