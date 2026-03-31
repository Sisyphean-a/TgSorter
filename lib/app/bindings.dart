import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final credentials = TdlibCredentials.fromEnvironment();
  final transport = TdClientTransport();
  final telegram = TelegramService(
    transport: transport,
    credentials: credentials,
  );

  Get.put(settingsRepo, permanent: true);
  Get.put(transport, permanent: true);
  Get.put(credentials, permanent: true);
  Get.put(telegram, permanent: true);

  Get.put(SettingsController(settingsRepo), permanent: true);
  Get.put(AuthController(telegram), permanent: true);
  Get.put(
    PipelineController(
      service: telegram,
      settingsController: Get.find<SettingsController>(),
    ),
    permanent: true,
  );
}
