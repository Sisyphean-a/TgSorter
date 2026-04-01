import 'dart:async';
import 'dart:developer' as developer;
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
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
  Stream<AuthorizationState> get authStates => _adapter.authorizationStates;

  @override
  Stream<ConnectionState> get connectionStates => _adapter.connectionStates;

  @override
  Future<void> start() => _adapter.start();

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
    final object = await _adapter.send(
      const GetChats(chatList: ChatListMain(), limit: _chatListLimit),
      request: 'getChats(main)',
      phase: TdlibPhase.business,
    );
    if (object is! Chats) {
      throw StateError('GetChats 返回类型异常: ${object.getConstructor()}');
    }
    final result = <SelectableChat>[];
    final failedChatIds = <int>[];
    for (final chatId in object.chatIds) {
      final chat = await _tryLoadChat(chatId);
      if (chat == null) {
        failedChatIds.add(chatId);
        continue;
      }
      if (!_isSelectableChatType(chat.type)) {
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
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required int messageId,
    required int targetChatId,
  }) async {
    await _requireAuthorizationReady();
    final actualSourceChatId = await _resolveSourceChatId(sourceChatId);
    final object = await _adapter.send(
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
    if (object is! Messages || object.messages.isEmpty) {
      throw StateError('forwardMessages 返回异常，无法提取目标消息 ID');
    }
    final targetMessageId = object.messages.first.id;

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
    final object = await _adapter.send(
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
    if (object is! Messages) {
      throw StateError('undo forward 返回非 Messages: ${object.getConstructor()}');
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
    final option = await _adapter.send(
      const GetOption(name: 'my_id'),
      request: 'getOption(my_id)',
      phase: TdlibPhase.business,
    );
    if (option is OptionValueInteger && option.value > 0) {
      _selfChatId = option.value;
      return;
    }
    final object = await _adapter.send(
      const GetMe(),
      request: 'getMe',
      phase: TdlibPhase.business,
      timeout: _getMeTimeout,
    );
    if (object is! User) {
      throw StateError('GetMe 返回类型异常: ${object.getConstructor()}');
    }
    _selfChatId = object.id;
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

  Future<void> _ensureMediaDownloadsStarted(MessageContent content) async {
    if (content is MessagePhoto) {
      await _ensureFileDownloadStarted(
        file: _pickPreviewPhotoFile(content.photo.sizes),
        priority: _downloadPriorityPhotoPreview,
      );
      return;
    }
    if (content is MessageVideo) {
      await _ensureFileDownloadStarted(
        file: content.video.thumbnail?.file,
        priority: _downloadPriorityVideoPreview,
      );
      await _ensureFileDownloadStarted(
        file: content.video.video,
        priority: _downloadPriorityVideoFile,
      );
    }
  }

  Future<void> _ensureFileDownloadStarted({
    required File? file,
    required int priority,
  }) async {
    if (file == null ||
        _isLocalFileReady(file.local) ||
        !file.local.canBeDownloaded) {
      return;
    }
    await _adapter.send(
      DownloadFile(
        fileId: file.id,
        priority: priority,
        offset: _downloadOffsetStart,
        limit: _downloadLimitUnlimited,
        synchronous: false,
      ),
      request: 'downloadFile',
      phase: TdlibPhase.business,
    );
  }

  Future<Message?> _fetchSavedMessage({
    required int chatId,
    required MessageFetchDirection direction,
  }) async {
    if (direction == MessageFetchDirection.oldestFirst) {
      return _fetchOldestSavedMessage(chatId);
    }
    return _fetchLatestSavedMessage(chatId);
  }

  Future<Message?> _fetchLatestSavedMessage(int chatId) async {
    final messages = await _fetchHistoryPage(
      chatId: chatId,
      fromMessageId: 0,
      limit: 1,
    );
    if (messages.isEmpty) {
      return null;
    }
    return messages.first;
  }

  Future<Message?> _fetchOldestSavedMessage(int chatId) async {
    var fromMessageId = 0;
    Message? oldest;

    while (true) {
      final page = await _fetchHistoryPage(
        chatId: chatId,
        fromMessageId: fromMessageId,
        limit: _historyBatchSize,
      );
      if (page.isEmpty) {
        return oldest;
      }

      oldest = page.last;
      if (page.length < _historyBatchSize) {
        return oldest;
      }

      if (page.last.id == fromMessageId) {
        throw StateError('获取最旧消息时游标未推进，history_id=$fromMessageId');
      }
      fromMessageId = page.last.id;
    }
  }

  Future<List<Message>> _fetchHistoryPage({
    required int chatId,
    required int fromMessageId,
    required int limit,
  }) async {
    final object = await _adapter.send(
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
    if (object is! Messages) {
      throw StateError('GetChatHistory 返回类型异常: ${object.getConstructor()}');
    }
    return object.messages;
  }

  PipelineMessage _toPipelineMessage(Message message, int sourceChatId) {
    return PipelineMessage(
      id: message.id,
      sourceChatId: sourceChatId,
      preview: mapMessagePreview(message.content),
    );
  }

  Future<Chat> _loadChat(int chatId) async {
    final object = await _adapter.send(
      GetChat(chatId: chatId),
      request: 'getChat($chatId)',
      phase: TdlibPhase.business,
      timeout: _getChatTimeout,
    );
    if (object is! Chat) {
      throw StateError('GetChat 返回类型异常: ${object.getConstructor()}');
    }
    return object;
  }

  Future<Chat?> _tryLoadChat(int chatId) async {
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

  bool _isSelectableChatType(ChatType type) {
    return type is ChatTypeBasicGroup || type is ChatTypeSupergroup;
  }

  File? _pickPreviewPhotoFile(List<PhotoSize> sizes) {
    if (sizes.isEmpty) {
      return null;
    }
    return sizes.last.photo;
  }

  bool _isLocalFileReady(LocalFile local) {
    return local.isDownloadingCompleted && local.path.isNotEmpty;
  }

  Future<void> _sendExpectOk(
    TdFunction function, {
    required String request,
    required TdlibPhase phase,
    Duration timeout = _defaultTimeout,
  }) async {
    final object = await _adapter.send(
      function,
      request: request,
      phase: phase,
      timeout: timeout,
    );
    if (object is! Ok) {
      throw StateError('请求返回非 Ok: ${object.getConstructor()}');
    }
  }

  Future<void> _sendExpectOkWithContext(
    TdFunction function, {
    required String requestLabel,
    Duration timeout = _defaultTimeout,
  }) async {
    final object = await _adapter.send(
      function,
      request: requestLabel,
      phase: TdlibPhase.business,
      timeout: timeout,
    );
    if (object is! Ok) {
      throw StateError('请求返回非 Ok: ${object.getConstructor()}');
    }
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
