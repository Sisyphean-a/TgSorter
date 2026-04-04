import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/core/di/auth_module.dart';
import 'package:tgsorter/app/core/di/pipeline_module.dart';
import 'package:tgsorter/app/core/di/settings_module.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/td_json_logger.dart';
import 'package:tgsorter/app/services/td_raw_transport.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_probe.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

Future<void> registerAppBindings() async {
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
    readProxySettings: () => settingsRepo.load().proxy,
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
  final telegram = TelegramService(
    adapter: adapter,
    journalRepository: journalRepo,
  );

  Get.put(settingsRepo, permanent: true);
  Get.put(journalRepo, permanent: true);
  Get.put(appErrors, permanent: true);
  Get.put(tdLogger, permanent: true);
  Get.put(rawTransport, permanent: true);
  Get.put(transport, permanent: true);
  Get.put(credentials, permanent: true);
  Get.put(adapter, permanent: true);
  Get.put<AuthGateway>(telegram, permanent: true);
  Get.put<SessionQueryGateway>(telegram, permanent: true);
  Get.put<AuthStateGateway>(telegram, permanent: true);
  Get.put<ConnectionStateGateway>(telegram, permanent: true);
  Get.put<MessageReadGateway>(telegram, permanent: true);
  Get.put<MediaGateway>(telegram, permanent: true);
  Get.put<ClassifyGateway>(telegram, permanent: true);
  Get.put<RecoveryGateway>(telegram, permanent: true);

  registerSettingsModule();
  registerAuthModule();
  registerPipelineModule();
}
