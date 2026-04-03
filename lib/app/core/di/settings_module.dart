import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void registerSettingsModule() {
  Get.put(
    SettingsCoordinator(
      Get.find<SettingsRepository>(),
      Get.find<TelegramGateway>(),
      auth: Get.find<TelegramGateway>(),
    ),
    permanent: true,
  );
}
