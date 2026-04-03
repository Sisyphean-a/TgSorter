import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_controller_legacy.dart';
import 'package:tgsorter/app/features/settings/application/settings_controller_legacy.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void registerAuthModule() {
  Get.put(
    AuthController(
      Get.find<TelegramGateway>(),
      Get.find<AppErrorController>(),
      Get.find<SettingsController>(),
    ),
    permanent: true,
  );
}
