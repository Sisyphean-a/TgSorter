import 'package:get/get.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';

class GetxAuthNavigationAdapter implements AuthNavigationPort {
  const GetxAuthNavigationAdapter();

  @override
  void goToApp() {
    Get.offNamed(AppRoutes.app);
  }

  @override
  void goToAuth() {
    Get.offAllNamed(AppRoutes.auth);
  }
}
