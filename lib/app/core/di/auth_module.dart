import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/core/routing/navigator_auth_navigation_adapter.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_coordinator.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';

void registerAuthModule() {
  final navigation = Get.put(NavigatorAuthNavigationAdapter(), permanent: true);
  Get.put<AuthNavigationPort>(navigation, permanent: true);
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
      lifecycle: lifecycle,
    ),
    permanent: true,
  );
}
