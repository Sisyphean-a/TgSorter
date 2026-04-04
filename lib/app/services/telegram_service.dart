import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/auth_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/connection_state_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/classify_transaction_coordinator.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_classify_workflow.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/services/telegram_media_service.dart';
import 'package:tgsorter/app/services/telegram_message_forwarder.dart';
import 'package:tgsorter/app/services/telegram_message_reader.dart';
import 'package:tgsorter/app/services/telegram_session_resolver.dart';

class TelegramService
    implements
        AuthGateway,
        SessionQueryGateway,
        AuthStateGateway,
        ConnectionStateGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway,
        TelegramGateway,
        RecoverableClassifyGateway {
  static const Duration _authorizationReadyTimeout = Duration(seconds: 20);
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const Duration _forwardDeliveryConfirmTimeoutDefault = Duration(
    seconds: 25,
  );
  static const Duration _forwardDeliveryPollIntervalDefault = Duration(
    milliseconds: 350,
  );

  TelegramService({
    required TdlibAdapter adapter,
    OperationJournalRepository? journalRepository,
    Duration forwardDeliveryConfirmTimeout =
        _forwardDeliveryConfirmTimeoutDefault,
    Duration forwardDeliveryPollInterval = _forwardDeliveryPollIntervalDefault,
  }) : _adapter = adapter,
       _journalRepository = journalRepository,
       _forwardDeliveryConfirmTimeout = forwardDeliveryConfirmTimeout,
       _forwardDeliveryPollInterval = forwardDeliveryPollInterval;

  final TdlibAdapter _adapter;
  final OperationJournalRepository? _journalRepository;
  final Duration _forwardDeliveryConfirmTimeout;
  final Duration _forwardDeliveryPollInterval;

  late final TelegramMessageForwarder _messageForwarder =
      TelegramMessageForwarder(
        adapter: _adapter,
        confirmTimeout: _forwardDeliveryConfirmTimeout,
        pollInterval: _forwardDeliveryPollInterval,
      );

  late final TelegramSessionResolver _sessionResolver = TelegramSessionResolver(
    adapter: _adapter,
  );

  late final TelegramMessageReader _messageReader = TelegramMessageReader(
    adapter: _adapter,
    defaultTimeout: _defaultTimeout,
  );

  late final TelegramMediaService _mediaService = TelegramMediaService(
    adapter: _adapter,
    reader: _messageReader,
  );

  late final ClassifyTransactionCoordinator _classifyCoordinator =
      ClassifyTransactionCoordinator(
        repository: _journalRepository,
        anySourceMessageExists: _anySourceMessageExists,
        deleteSourceMessages: _deleteSourceMessagesForRecovery,
        nowMs: _nowMs,
        buildTransactionId: _buildClassifyTransactionId,
      );

  late final TelegramClassifyWorkflow _classifyWorkflow =
      TelegramClassifyWorkflow(
        forwardMessagesAndConfirmDelivery:
            _messageForwarder.forwardMessagesAndConfirmDelivery,
        deleteMessages: _deleteMessages,
        transactionCoordinator: _classifyCoordinator,
      );

  @override
  Stream<TdAuthState> get authStates => _adapter.authorizationStates;

  @override
  Stream<TdConnectionState> get connectionStates => _adapter.connectionStates;

  @override
  Future<void> start() => _adapter.start();

  @override
  Future<void> restart() => _adapter.restart();

  @override
  Future<void> submitPhoneNumber(String phoneNumber) =>
      _adapter.submitPhoneNumber(phoneNumber);

  @override
  Future<void> submitCode(String code) => _adapter.submitCode(code);

  @override
  Future<void> submitPassword(String password) =>
      _adapter.submitPassword(password);

  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    await _requireAuthorizationReady();
    return _sessionResolver.listSelectableChats();
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
    await _requireAuthorizationReady();
    final chatId = await _sessionResolver.resolveSourceChatId(sourceChatId);
    return _messageReader.countRemainingMessages(chatId);
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    await _requireAuthorizationReady();
    final chatId = await _sessionResolver.resolveSourceChatId(sourceChatId);
    return _messageReader.fetchMessagePage(
      direction: direction,
      sourceChatId: chatId,
      fromMessageId: fromMessageId,
      limit: limit,
    );
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    await _requireAuthorizationReady();
    final chatId = await _sessionResolver.resolveSourceChatId(sourceChatId);
    return _messageReader.fetchNextMessage(
      direction: direction,
      sourceChatId: chatId,
    );
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    return _mediaService.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    await _mediaService.prepareMediaPreview(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    return _messageReader.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    await _requireAuthorizationReady();
    final actualSourceChatId = await _sessionResolver.resolveSourceChatId(
      sourceChatId,
    );
    return _classifyWorkflow.classifyMessage(
      sourceChatId: actualSourceChatId,
      sourceMessageIds: messageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {
    await _requireAuthorizationReady();
    await _classifyWorkflow.undoClassify(
      sourceChatId: sourceChatId,
      targetChatId: targetChatId,
      targetMessageIds: targetMessageIds,
    );
  }

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    await _requireAuthorizationReady();
    return _classifyWorkflow.recoverPendingClassifyOperations();
  }

  Future<bool> _anySourceMessageExists(
    ClassifyTransactionEntry transaction,
  ) async {
    for (final messageId in transaction.sourceMessageIds) {
      try {
        await _messageReader.loadMessage(transaction.sourceChatId, messageId);
        return true;
      } on TdlibFailure catch (error) {
        if (_isMessageMissingFailure(error)) {
          continue;
        }
        rethrow;
      }
    }
    return false;
  }

  Future<void> _deleteSourceMessagesForRecovery(
    ClassifyTransactionEntry transaction,
  ) async {
    await _deleteMessages(
      chatId: transaction.sourceChatId,
      messageIds: transaction.sourceMessageIds,
      requestLabel: 'deleteMessages(recover)',
    );
  }

  Future<void> _deleteMessages({
    required int chatId,
    required List<int> messageIds,
    required String requestLabel,
  }) {
    return _sendExpectOk(
      DeleteMessages(chatId: chatId, messageIds: messageIds, revoke: true),
      request: requestLabel,
      phase: TdlibPhase.business,
    );
  }

  bool _isMessageMissingFailure(TdlibFailure error) {
    if (error.code == 404) {
      return true;
    }
    final message = error.message.toLowerCase();
    return error.code == 400 && message.contains('not found');
  }

  String _buildClassifyTransactionId({
    required int sourceChatId,
    required List<int> sourceMessageIds,
  }) {
    final first = sourceMessageIds.isEmpty ? 0 : sourceMessageIds.first;
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'tx-$sourceChatId-$first-$now';
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Future<void> _sendExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = _defaultTimeout,
  }) async {
    await _adapter.sendWireExpectOk(
      function,
      request: request,
      phase: phase,
      timeout: timeout,
    );
  }

  Future<void> _requireAuthorizationReady() {
    return _adapter.waitUntilReady().timeout(
      _authorizationReadyTimeout,
      onTimeout: () {
        throw StateError('TDLib 授权未就绪，无法执行当前请求');
      },
    );
  }
}
