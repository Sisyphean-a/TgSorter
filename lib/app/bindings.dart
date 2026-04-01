import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/auth_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/td_json_logger.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_probe.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

Future<void> initDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final journalRepo = OperationJournalRepository(prefs);
  final appErrors = AppErrorController();
  final credentials = TdlibCredentials.fromEnvironment();
  final tdLogger = TdJsonLogger();
  final rawTransport = TdRawTransport(logger: tdLogger);
  final transport = TdClientTransport(
    rawTransport: rawTransport,
    logger: tdLogger,
  );
  final runtimePaths = await resolveTdlibRuntimePaths();
  final adapter = TdlibAdapter(
    transport: transport,
    rawTransport: rawTransport,
    credentials: credentials,
    runtimePaths: runtimePaths,
    detectCapabilities: () {
      final probe = TdlibSchemaProbe(
        send: (function) async => TdWireEnvelope.fromJson(
          await rawTransport.send(
            function,
            timeout: const Duration(seconds: 8),
          ),
        ),
      );
      return probe.detect();
    },
    initializeTdlib: defaultTdlibInitializer,
  );
  final telegram = TelegramService(adapter: adapter);

  Get.put(settingsRepo, permanent: true);
  Get.put(journalRepo, permanent: true);
  Get.put(appErrors, permanent: true);
  Get.put(tdLogger, permanent: true);
  Get.put(rawTransport, permanent: true);
  Get.put(transport, permanent: true);
  Get.put(credentials, permanent: true);
  Get.put(adapter, permanent: true);
  Get.put(telegram, permanent: true);

  Get.put(SettingsController(settingsRepo, telegram), permanent: true);
  Get.put(AuthController(telegram, appErrors), permanent: true);
  Get.put(
    PipelineController(
      service: telegram,
      settingsController: Get.find<SettingsController>(),
      journalRepository: Get.find<OperationJournalRepository>(),
      errorController: appErrors,
    ),
    permanent: true,
  );
}
