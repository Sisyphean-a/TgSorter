import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/core/di/auth_module.dart';
import 'package:tgsorter/app/core/di/download_module.dart';
import 'package:tgsorter/app/core/di/pipeline_module.dart';
import 'package:tgsorter/app/core/di/settings_module.dart';
import 'package:tgsorter/app/core/di/tagging_module.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/login_alerts/application/login_alert_workbench_controller.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_registry.dart';
import 'package:tgsorter/app/features/tagging/ports/tagging_gateway.dart';
import 'package:tgsorter/app/services/download_sync_repository.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';
import 'package:tgsorter/app/services/login_alert_repository.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';
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
  final downloadSyncRepo = DownloadSyncRepository(prefs);
  final loginAlertRepo = LoginAlertRepository(prefs);
  final skippedMessageRepo = SkippedMessageRepository(prefs);
  final skippedRestoreRegistry = SkippedMessageRestoreRegistry();
  final appErrors = AppErrorController();
  final credentials = TdlibCredentials.fromEnvironment();
  const tdLogDetailRaw = String.fromEnvironment(
    'TD_LOG_DETAIL',
    defaultValue: 'summary',
  );
  final tdLogger = TdJsonLogger(
    detailLevel: parseTdJsonLogDetailLevel(tdLogDetailRaw),
  );
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
  final downloadSync = DownloadSyncService(
    messages: telegram,
    media: telegram,
    repository: downloadSyncRepo,
  );
  final loginAlerts = LoginAlertWorkbenchController(
    updates: rawTransport.updates,
    repository: loginAlertRepo,
  );

  Get.put(settingsRepo, permanent: true);
  Get.put(journalRepo, permanent: true);
  Get.put(downloadSyncRepo, permanent: true);
  Get.put<LoginAlertRepositoryPort>(loginAlertRepo, permanent: true);
  Get.put(skippedMessageRepo, permanent: true);
  Get.put(skippedRestoreRegistry, permanent: true);
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
  Get.put<TaggingGateway>(telegram, permanent: true);
  Get.put<DownloadSyncPort>(downloadSync, permanent: true);
  Get.put(loginAlerts, permanent: true);

  registerSettingsModule();
  registerAuthModule();
  registerPipelineModule();
  registerTaggingModule();
  registerDownloadModule();
}
