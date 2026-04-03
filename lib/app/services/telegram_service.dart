import 'dart:async';
import 'dart:developer' as developer;
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_builder.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/classify_transaction_coordinator.dart';
import 'package:tgsorter/app/services/media_download_coordinator.dart';
import 'package:tgsorter/app/services/message_history_paginator.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_chat_dto.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class TelegramService implements TelegramGateway, RecoverableClassifyGateway {
  static const int _historyBatchSize = 100;
  static const int _chatListLimit = 200;
  static const int _maxSelectableChats = 120;
  static const Duration _authorizationReadyTimeout = Duration(seconds: 20);
  static const Duration _getMeTimeout = Duration(seconds: 60);
  static const Duration _getChatTimeout = Duration(seconds: 8);
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

  int? _selfChatId;

  late final MessageHistoryPaginator _historyPaginator =
      MessageHistoryPaginator(
        adapter: _adapter,
        defaultTimeout: _defaultTimeout,
        historyBatchSize: _historyBatchSize,
      );

  late final MediaDownloadCoordinator _mediaDownloadCoordinator =
      MediaDownloadCoordinator(adapter: _adapter);

  static const MessagePreviewBuilder _previewBuilder = MessagePreviewBuilder();

  late final ClassifyTransactionCoordinator _classifyCoordinator =
      ClassifyTransactionCoordinator(
        repository: _journalRepository,
        anySourceMessageExists: _anySourceMessageExists,
        deleteSourceMessages: _deleteSourceMessagesForRecovery,
        nowMs: _nowMs,
        buildTransactionId: _buildClassifyTransactionId,
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
    await _loadChatsMainUntilDone();
    final envelope = await _adapter.sendWire(
      const GetChats(chatList: ChatListMain(), limit: _chatListLimit),
      request: 'getChats(main)',
      phase: TdlibPhase.business,
    );
    final chats = TdChatListDto.fromEnvelope(envelope);
    final result = <SelectableChat>[];
    final failedChatIds = <int>[];
    for (final chatId in chats.chatIds) {
      final chat = await _tryLoadChat(chatId);
      if (chat == null) {
        failedChatIds.add(chatId);
        continue;
      }
      if (!chat.isSelectable) {
        continue;
      }
      result.add(SelectableChat(id: chat.id, title: chat.title));
      if (result.length >= _maxSelectableChats) {
        break;
      }
    }
    if (failedChatIds.isNotEmpty) {
      developer.log(
        '部分会话详情拉取失败，failed=${failedChatIds.length}',
        name: 'TelegramService',
      );
    }
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
    await _requireAuthorizationReady();
    final chatId = await _resolveSourceChatId(sourceChatId);
    final messages = await _historyPaginator.fetchAllHistoryMessages(chatId);
    return messages.length;
  }

  Future<void> _loadChatsMainUntilDone() async {
    while (true) {
      try {
        await _sendExpectOkWithContext(
          const LoadChats(chatList: ChatListMain(), limit: _chatListLimit),
          requestLabel: 'loadChats(main)',
        );
      } on TdlibFailure catch (error) {
        final isLoadedDone = error.code == 404;
        if (isLoadedDone) {
          return;
        }
        rethrow;
      }
    }
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    await _requireAuthorizationReady();
    final chatId = await _resolveSourceChatId(sourceChatId);
    final messages = await _historyPaginator.fetchSavedMessagePage(
      chatId: chatId,
      direction: direction,
      fromMessageId: fromMessageId,
      limit: limit,
    );
    for (final item in messages) {
      await _mediaDownloadCoordinator.warmUpPreview(item.content);
    }
    return _previewBuilder.groupPipelineMessages(
      messages: messages,
      sourceChatId: chatId,
      direction: direction,
    );
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    await _requireAuthorizationReady();
    final chatId = await _resolveSourceChatId(sourceChatId);
    final message = await _historyPaginator.fetchSavedMessage(
      chatId: chatId,
      direction: direction,
    );
    if (message == null) {
      return null;
    }
    await _mediaDownloadCoordinator.warmUpPreview(message.content);
    return _previewBuilder.toPipelineMessage(
      messages: <TdMessageDto>[message],
      sourceChatId: chatId,
    );
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    final message = await _loadMessage(sourceChatId, messageId);
    final content = message.content;
    await _mediaDownloadCoordinator.preparePlayback(content);
    if (content.kind != TdMessageContentKind.audio &&
        content.kind != TdMessageContentKind.video) {
      return _previewBuilder.toPipelineMessage(
        messages: <TdMessageDto>[message],
        sourceChatId: sourceChatId,
      );
    }
    return refreshMessage(sourceChatId: sourceChatId, messageId: messageId);
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    final message = await _loadMessage(sourceChatId, messageId);
    await _mediaDownloadCoordinator.warmUpPreview(message.content);
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    final message = await _loadMessage(sourceChatId, messageId);
    return _previewBuilder.toPipelineMessage(
      messages: <TdMessageDto>[message],
      sourceChatId: sourceChatId,
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
    final actualSourceChatId = await _resolveSourceChatId(sourceChatId);
    final startedTransaction = await _classifyCoordinator.startTransaction(
      sourceChatId: actualSourceChatId,
      sourceMessageIds: messageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
    );
    var transaction = startedTransaction;
    try {
      final targetMessageIds = await _forwardMessagesAndConfirmDelivery(
        targetChatId: targetChatId,
        sourceChatId: actualSourceChatId,
        sourceMessageIds: messageIds,
        sendCopy: asCopy,
        requestLabel: 'forwardMessages',
      );
      transaction = await _classifyCoordinator.markForwardConfirmed(
        transaction,
        targetMessageIds: targetMessageIds,
      );

      await _sendExpectOk(
        DeleteMessages(
          chatId: actualSourceChatId,
          messageIds: messageIds,
          revoke: true,
        ),
        request: 'deleteMessages',
        phase: TdlibPhase.business,
      );

      await _classifyCoordinator.markSourceDeleteConfirmed(transaction);

      return ClassifyReceipt(
        sourceChatId: actualSourceChatId,
        sourceMessageIds: messageIds,
        targetChatId: targetChatId,
        targetMessageIds: targetMessageIds,
      );
    } catch (error) {
      await _classifyCoordinator.recordFailure(transaction, error);
      rethrow;
    }
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {
    await _requireAuthorizationReady();
    await _forwardMessagesAndConfirmDelivery(
      targetChatId: sourceChatId,
      sourceChatId: targetChatId,
      sourceMessageIds: targetMessageIds,
      sendCopy: true,
      requestLabel: 'undo forward',
    );
    await _sendExpectOk(
      DeleteMessages(
        chatId: targetChatId,
        messageIds: targetMessageIds,
        revoke: true,
      ),
      request: 'deleteMessages',
      phase: TdlibPhase.business,
    );
  }

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    await _requireAuthorizationReady();
    return _classifyCoordinator.recoverPendingTransactions();
  }

  Future<bool> _anySourceMessageExists(
    ClassifyTransactionEntry transaction,
  ) async {
    for (final messageId in transaction.sourceMessageIds) {
      try {
        await _loadMessage(transaction.sourceChatId, messageId);
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
    await _sendExpectOk(
      DeleteMessages(
        chatId: transaction.sourceChatId,
        messageIds: transaction.sourceMessageIds,
        revoke: true,
      ),
      request: 'deleteMessages(recover)',
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

  Future<List<int>> _forwardMessagesAndConfirmDelivery({
    required int targetChatId,
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required bool sendCopy,
    required String requestLabel,
  }) async {
    final envelope = await _adapter.sendWire(
      ForwardMessages(
        chatId: targetChatId,
        messageThreadId: 0,
        fromChatId: sourceChatId,
        messageIds: sourceMessageIds,
        options: null,
        sendCopy: sendCopy,
        removeCaption: false,
        onlyPreview: false,
      ),
      request: 'forwardMessages',
      phase: TdlibPhase.business,
    );
    final forwarded = _parseForwardedMessageDeliveries(envelope);
    if (forwarded.isEmpty) {
      throw StateError('$requestLabel 返回异常，无法提取目标消息 ID');
    }
    if (forwarded.length != sourceMessageIds.length) {
      throw StateError(
        '$requestLabel 返回数量异常，source=${sourceMessageIds.length},target=${forwarded.length}',
      );
    }
    for (final item in forwarded) {
      if (!item.delivery.isFailed) {
        continue;
      }
      throw StateError(
        '$requestLabel 目标消息发送失败: message_id=${item.messageId},reason=${item.delivery.failureReason}',
      );
    }
    await _waitPendingForwardedMessages(
      targetChatId: targetChatId,
      requestLabel: requestLabel,
      forwarded: forwarded,
    );
    return forwarded.map((item) => item.messageId).toList(growable: false);
  }

  List<_ForwardedMessageDelivery> _parseForwardedMessageDeliveries(
    TdWireEnvelope envelope,
  ) {
    final rawMessages = TdResponseReader.readList(envelope.payload, 'messages');
    return rawMessages
        .map((item) {
          final payload = TdResponseReader.readMap(<String, dynamic>{
            'item': item,
          }, 'item');
          return _ForwardedMessageDelivery(
            messageId: TdResponseReader.readInt(payload, 'id'),
            delivery: _readMessageDeliveryState(payload),
          );
        })
        .toList(growable: false);
  }

  Future<void> _waitPendingForwardedMessages({
    required int targetChatId,
    required String requestLabel,
    required List<_ForwardedMessageDelivery> forwarded,
  }) async {
    final pendingIds = forwarded
        .where((item) => item.delivery.isPending)
        .map((item) => item.messageId)
        .toSet();
    if (pendingIds.isEmpty) {
      return;
    }
    final deadline = DateTime.now().add(_forwardDeliveryConfirmTimeout);
    while (pendingIds.isNotEmpty) {
      final snapshot = pendingIds.toList(growable: false);
      for (final messageId in snapshot) {
        if (messageId <= 0) {
          throw StateError(
            '$requestLabel 返回临时消息 ID($messageId)，发送状态未确认，已中止删除源消息',
          );
        }
        final envelope = await _adapter.sendWire(
          GetMessage(chatId: targetChatId, messageId: messageId),
          request: 'getMessage($targetChatId,$messageId)',
          phase: TdlibPhase.business,
        );
        final delivery = _readMessageDeliveryState(envelope.payload);
        if (delivery.isSent) {
          pendingIds.remove(messageId);
          continue;
        }
        if (delivery.isFailed) {
          throw StateError(
            '$requestLabel 目标消息发送失败: message_id=$messageId,reason=${delivery.failureReason}',
          );
        }
      }
      if (pendingIds.isEmpty) {
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          '$requestLabel 发送状态确认超时，pending=${pendingIds.join(",")}，已中止删除源消息',
        );
      }
      await Future<void>.delayed(_forwardDeliveryPollInterval);
    }
  }

  _MessageDeliveryState _readMessageDeliveryState(
    Map<String, dynamic> messagePayload,
  ) {
    final sendingState = _readDynamicMap(messagePayload['sending_state']);
    if (sendingState == null) {
      return const _MessageDeliveryState.sent();
    }
    final type = sendingState['@type']?.toString() ?? '';
    if (type != 'messageSendingStateFailed') {
      return const _MessageDeliveryState.pending();
    }
    final error = _readDynamicMap(sendingState['error']);
    final code = error?['code']?.toString();
    final message = error?['message']?.toString();
    final reason = <String>[
      if (code != null && code.isNotEmpty) 'code=$code',
      if (message != null && message.isNotEmpty) 'message=$message',
    ].join(',');
    return _MessageDeliveryState.failed(reason.isEmpty ? 'unknown' : reason);
  }

  Map<String, dynamic>? _readDynamicMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is! Map) {
      return null;
    }
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _loadSelfChatId() async {
    final option = await _adapter.sendWire(
      const GetOption(name: 'my_id'),
      request: 'getOption(my_id)',
      phase: TdlibPhase.business,
    );
    if (option.type == 'optionValueInteger') {
      final myId = TdOptionMyIdDto.fromEnvelope(option);
      if (myId.value > 0) {
        _selfChatId = await _createPrivateChatId(myId.value);
        return;
      }
    }
    final me = await _adapter.sendWire(
      const GetMe(),
      request: 'getMe',
      phase: TdlibPhase.business,
      timeout: _getMeTimeout,
    );
    final myId = TdSelfDto.fromEnvelope(me).id;
    _selfChatId = await _createPrivateChatId(myId);
  }

  Future<int> _createPrivateChatId(int userId) async {
    final chat = await _adapter.sendWire(
      CreatePrivateChat(userId: userId, force: false),
      request: 'createPrivateChat($userId)',
      phase: TdlibPhase.business,
    );
    return TdChatDto.fromEnvelope(chat).id;
  }

  Future<int> _requireSelfChatId() async {
    final chatId = _selfChatId;
    if (chatId != null) {
      return chatId;
    }
    await _loadSelfChatId();
    final fresh = _selfChatId;
    if (fresh == null) {
      throw StateError('无法获取 Saved Messages 的 chat_id');
    }
    return fresh;
  }

  Future<int> _resolveSourceChatId(int? sourceChatId) async {
    if (sourceChatId != null) {
      return sourceChatId;
    }
    return _requireSelfChatId();
  }

  Future<TdChatDto> _loadChat(int chatId) async {
    final envelope = await _adapter.sendWire(
      GetChat(chatId: chatId),
      request: 'getChat($chatId)',
      phase: TdlibPhase.business,
      timeout: _getChatTimeout,
    );
    return TdChatDto.fromEnvelope(envelope);
  }

  Future<TdMessageDto> _loadMessage(int chatId, int messageId) async {
    final envelope = await _adapter.sendWire(
      GetMessage(chatId: chatId, messageId: messageId),
      request: 'getMessage($chatId,$messageId)',
      phase: TdlibPhase.business,
    );
    return TdMessageDto.fromJson(envelope.payload);
  }

  Future<TdChatDto?> _tryLoadChat(int chatId) async {
    try {
      return await _loadChat(chatId);
    } catch (error, stack) {
      developer.log(
        'getChat($chatId) 失败: $error',
        name: 'TelegramService',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }

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

  Future<void> _sendExpectOkWithContext(
    TdFunction function, {
    required String requestLabel,
    Duration timeout = _defaultTimeout,
  }) async {
    await _adapter.sendWireExpectOk(
      function,
      request: requestLabel,
      phase: TdlibPhase.business,
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

class _ForwardedMessageDelivery {
  const _ForwardedMessageDelivery({
    required this.messageId,
    required this.delivery,
  });

  final int messageId;
  final _MessageDeliveryState delivery;
}

class _MessageDeliveryState {
  const _MessageDeliveryState._({
    required this.isSent,
    required this.isPending,
    required this.failureReason,
  });

  const _MessageDeliveryState.sent()
    : this._(isSent: true, isPending: false, failureReason: null);

  const _MessageDeliveryState.pending()
    : this._(isSent: false, isPending: true, failureReason: null);

  const _MessageDeliveryState.failed(String reason)
    : this._(isSent: false, isPending: false, failureReason: reason);

  final bool isSent;
  final bool isPending;
  final String? failureReason;

  bool get isFailed => failureReason != null;
}
