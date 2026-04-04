import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/core/routing/getx_auth_navigation_adapter.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';

void registerAuthModule() {
  Get.put<AuthNavigationPort>(
    const GetxAuthNavigationAdapter(),
    permanent: true,
  );
  final lifecycle = AuthLifecycleCoordinator(
    auth: Get.find<AuthGateway>(),
    errors: Get.find<AppErrorController>(),
    errorMapper: const AuthErrorMapper(),
    navigation: Get.find<AuthNavigationPort>(),
  );
  Get.put(
    AuthCoordinator(
      Get.find<AuthGateway>(),
      Get.find<AppErrorController>(),
      Get.find<SettingsCoordinator>(),
      lifecycle: lifecycle,
    ),
    permanent: true,
  );
}
