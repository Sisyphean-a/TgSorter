import 'dart:async';
import 'dart:developer' as developer;
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_chat_dto.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class TelegramService implements TelegramGateway {
  static const int _downloadPriorityPhotoPreview = 16;
  static const int _downloadPriorityVideoPreview = 17;
  static const int _downloadPriorityVideoFile = 20;
  static const int _downloadOffsetStart = 0;
  static const int _downloadLimitUnlimited = 0;
  static const int _historyBatchSize = 100;
  static const int _chatListLimit = 200;
  static const int _maxSelectableChats = 120;
  static const Duration _authorizationReadyTimeout = Duration(seconds: 20);
  static const Duration _getMeTimeout = Duration(seconds: 60);
  static const Duration _getChatTimeout = Duration(seconds: 8);
  static const Duration _defaultTimeout = Duration(seconds: 20);

  TelegramService({required TdlibAdapter adapter}) : _adapter = adapter;

  final TdlibAdapter _adapter;

  int? _selfChatId;

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
    final messages = await _fetchSavedMessagePage(
      chatId: chatId,
      direction: direction,
      fromMessageId: fromMessageId,
      limit: limit,
    );
    for (final item in messages) {
      await _ensureMediaDownloadsStarted(item.content);
    }
    return messages
        .map((item) => _toPipelineMessage(item, chatId))
        .toList(growable: false);
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    await _requireAuthorizationReady();
    final chatId = await _resolveSourceChatId(sourceChatId);
    final message = await _fetchSavedMessage(
      chatId: chatId,
      direction: direction,
    );
    if (message == null) {
      return null;
    }
    await _ensureMediaDownloadsStarted(message.content);
    return _toPipelineMessage(message, chatId);
  }

  @override
  Future<PipelineMessage> prepareVideoPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    final message = await _loadMessage(sourceChatId, messageId);
    final content = message.content;
    if (content.kind != TdMessageContentKind.video) {
      return _toPipelineMessage(message, sourceChatId);
    }
    await _ensureFileDownloadStarted(
      fileId: content.remoteVideoFileId,
      localPath: content.localVideoPath,
      priority: _downloadPriorityVideoFile,
    );
    return refreshMessage(sourceChatId: sourceChatId, messageId: messageId);
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    await _requireAuthorizationReady();
    final message = await _loadMessage(sourceChatId, messageId);
    return _toPipelineMessage(message, sourceChatId);
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required int messageId,
    required int targetChatId,
  }) async {
    await _requireAuthorizationReady();
    final actualSourceChatId = await _resolveSourceChatId(sourceChatId);
    final envelope = await _adapter.sendWire(
      ForwardMessages(
        chatId: targetChatId,
        messageThreadId: 0,
        fromChatId: actualSourceChatId,
        messageIds: [messageId],
        options: null,
        sendCopy: false,
        removeCaption: false,
        onlyPreview: false,
      ),
      request: 'forwardMessages',
      phase: TdlibPhase.business,
    );
    final forwarded = TdMessagesDto.fromEnvelope(envelope);
    if (forwarded.messages.isEmpty) {
      throw StateError('forwardMessages 返回异常，无法提取目标消息 ID');
    }
    final targetMessageId = forwarded.messages.first.id;

    await _sendExpectOk(
      DeleteMessages(
        chatId: actualSourceChatId,
        messageIds: [messageId],
        revoke: true,
      ),
      request: 'deleteMessages',
      phase: TdlibPhase.business,
    );

    return ClassifyReceipt(
      sourceChatId: actualSourceChatId,
      sourceMessageId: messageId,
      targetChatId: targetChatId,
      targetMessageId: targetMessageId,
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required int targetMessageId,
  }) async {
    await _requireAuthorizationReady();
    final envelope = await _adapter.sendWire(
      ForwardMessages(
        chatId: sourceChatId,
        messageThreadId: 0,
        fromChatId: targetChatId,
        messageIds: [targetMessageId],
        options: null,
        sendCopy: true,
        removeCaption: false,
        onlyPreview: false,
      ),
      request: 'forwardMessages',
      phase: TdlibPhase.business,
    );
    final forwarded = TdMessagesDto.fromEnvelope(envelope);
    if (forwarded.messages.isEmpty) {
      throw StateError('undo forward 返回空消息列表');
    }
    await _sendExpectOk(
      DeleteMessages(
        chatId: targetChatId,
        messageIds: [targetMessageId],
        revoke: true,
      ),
      request: 'deleteMessages',
      phase: TdlibPhase.business,
    );
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
        _selfChatId = myId.value;
        return;
      }
    }
    final me = await _adapter.sendWire(
      const GetMe(),
      request: 'getMe',
      phase: TdlibPhase.business,
      timeout: _getMeTimeout,
    );
    _selfChatId = TdSelfDto.fromEnvelope(me).id;
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

  Future<void> _ensureMediaDownloadsStarted(TdMessageContentDto content) async {
    if (content.kind == TdMessageContentKind.photo) {
      await _ensureFileDownloadStarted(
        fileId: content.remoteImageFileId,
        localPath: content.localImagePath,
        priority: _downloadPriorityPhotoPreview,
      );
      return;
    }
    if (content.kind == TdMessageContentKind.video) {
      await _ensureFileDownloadStarted(
        fileId: content.remoteVideoThumbnailFileId,
        localPath: content.localVideoThumbnailPath,
        priority: _downloadPriorityVideoPreview,
      );
    }
  }

  Future<void> _ensureFileDownloadStarted({
    required int? fileId,
    required String? localPath,
    required int priority,
  }) async {
    if (fileId == null || (localPath != null && localPath.isNotEmpty)) {
      return;
    }
    await _adapter.sendWire(
      DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: _downloadOffsetStart,
        limit: _downloadLimitUnlimited,
        synchronous: false,
      ),
      request: 'downloadFile',
      phase: TdlibPhase.business,
    );
  }

  Future<TdMessageDto?> _fetchSavedMessage({
    required int chatId,
    required MessageFetchDirection direction,
  }) async {
    final page = await _fetchSavedMessagePage(
      chatId: chatId,
      direction: direction,
      fromMessageId: null,
      limit: 1,
    );
    if (page.isEmpty) {
      return null;
    }
    return page.first;
  }

  Future<List<TdMessageDto>> _fetchSavedMessagePage({
    required int chatId,
    required MessageFetchDirection direction,
    required int? fromMessageId,
    required int limit,
  }) async {
    if (direction == MessageFetchDirection.oldestFirst) {
      return _fetchOldestSavedMessagePage(
        chatId: chatId,
        fromMessageId: fromMessageId,
        limit: limit,
      );
    }
    return _fetchLatestSavedMessagePage(
      chatId: chatId,
      fromMessageId: fromMessageId,
      limit: limit,
    );
  }

  Future<List<TdMessageDto>> _fetchLatestSavedMessagePage({
    required int chatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    final messages = await _fetchHistoryPage(
      chatId: chatId,
      fromMessageId: fromMessageId ?? 0,
      limit: fromMessageId == null ? limit : limit + 1,
    );
    if (fromMessageId == null) {
      return messages;
    }
    return messages.where((item) => item.id != fromMessageId).take(limit).toList(
      growable: false,
    );
  }

  Future<List<TdMessageDto>> _fetchOldestSavedMessagePage({
    required int chatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    final all = <TdMessageDto>[];
    var cursor = 0;
    while (true) {
      final page = await _fetchHistoryPage(
        chatId: chatId,
        fromMessageId: cursor,
        limit: _historyBatchSize,
      );
      if (page.isEmpty) {
        break;
      }
      all.addAll(page);
      if (page.length < _historyBatchSize) {
        break;
      }
      if (page.last.id == cursor) {
        throw StateError('获取最旧消息时游标未推进，history_id=$cursor');
      }
      cursor = page.last.id;
    }
    final ordered = all.reversed.toList(growable: false);
    if (fromMessageId == null) {
      return ordered.take(limit).toList(growable: false);
    }
    final start = ordered.indexWhere((item) => item.id == fromMessageId);
    if (start < 0) {
      return const [];
    }
    return ordered.skip(start + 1).take(limit).toList(growable: false);
  }

  Future<List<TdMessageDto>> _fetchHistoryPage({
    required int chatId,
    required int fromMessageId,
    required int limit,
  }) async {
    final envelope = await _adapter.sendWire(
      GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        onlyLocal: false,
      ),
      request: 'getChatHistory',
      phase: TdlibPhase.business,
    );
    return TdMessagesDto.fromEnvelope(envelope).messages;
  }

  PipelineMessage _toPipelineMessage(TdMessageDto message, int sourceChatId) {
    return PipelineMessage(
      id: message.id,
      sourceChatId: sourceChatId,
      preview: mapMessagePreview(message.content),
    );
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
