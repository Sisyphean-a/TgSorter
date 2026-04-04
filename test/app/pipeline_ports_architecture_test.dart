import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

void main() {
  test('pipeline coordinator exposes settings-facing logs port', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gateway = _PipelinePortGateway();
    final coordinator = PipelineCoordinator(
      authStateGateway: gateway,
      connectionStateGateway: gateway,
      messageReadGateway: gateway,
      mediaGateway: gateway,
      classifyGateway: gateway,
      recoveryGateway: gateway,
      settingsReader: _PipelinePortSettingsReader(),
      journalRepository: OperationJournalRepository(prefs),
      errorController: AppErrorController(),
    );

    expect(coordinator, isA<PipelineLogsPort>());
  });
}

class _PipelinePortSettingsReader implements PipelineSettingsReader {
  @override
  AppSettings get currentSettings => AppSettings.defaults();

  @override
  CategoryConfig getCategory(String key) => throw UnimplementedError();

  @override
  Rx<AppSettings> get settingsStream => AppSettings.defaults().obs;
}

class _PipelinePortGateway
    implements
        AuthStateGateway,
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway {
  final _connectionStates = StreamController<TdConnectionState>.broadcast();

  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async => throw UnimplementedError();

  @override
  Stream<TdConnectionState> get connectionStates => _connectionStates.stream;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async => const [];

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async => null;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async => throw UnimplementedError();

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async => throw UnimplementedError();

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async =>
      ClassifyRecoverySummary.empty;

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}
}
