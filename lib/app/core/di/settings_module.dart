import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_controller_legacy.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void registerSettingsModule() {
  Get.put(
    SettingsController(
      Get.find<SettingsRepository>(),
      Get.find<TelegramGateway>(),
    ),
    permanent: true,
  );
}
