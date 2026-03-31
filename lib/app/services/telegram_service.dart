import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class TdlibRequestException implements Exception {
  TdlibRequestException({required this.code, required this.message});

  final int code;
  final String message;

  @override
  String toString() => 'TDLib 请求失败($code): $message';
}

class TelegramService implements TelegramGateway {
  static const int _downloadPriorityPhotoPreview = 16;
  static const int _downloadPriorityVideoPreview = 17;
  static const int _downloadPriorityVideoFile = 20;
  static const int _downloadOffsetStart = 0;
  static const int _downloadLimitUnlimited = 0;
  static const int _historyBatchSize = 100;
  static const int _tdLogVerbosityLevel = 1;

  TelegramService({
    required TdClientTransport transport,
    required TdlibCredentials credentials,
  }) : _transport = transport,
       _credentials = credentials;

  final TdClientTransport _transport;
  final TdlibCredentials _credentials;

  final _authStateController = StreamController<AuthorizationState>.broadcast();
  final _connectionController = StreamController<ConnectionState>.broadcast();

  StreamSubscription<TdObject>? _updatesSub;
  int? _selfChatId;

  @override
  Stream<AuthorizationState> get authStates => _authStateController.stream;

  @override
  Stream<ConnectionState> get connectionStates => _connectionController.stream;

  @override
  Future<void> start() async {
    await TdPlugin.initialize();
    await _transport.start();
    _updatesSub ??= _transport.updates.listen(_handleUpdate);
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) {
    return _sendExpectOk(
      SetAuthenticationPhoneNumber(phoneNumber: phoneNumber),
    );
  }

  @override
  Future<void> submitCode(String code) {
    return _sendExpectOk(CheckAuthenticationCode(code: code));
  }

  @override
  Future<void> submitPassword(String password) {
    return _sendExpectOk(CheckAuthenticationPassword(password: password));
  }

  @override
  Future<PipelineMessage?> fetchNextSavedMessage({
    required MessageFetchDirection direction,
  }) async {
    final chatId = await _requireSelfChatId();
    final message = await _fetchSavedMessage(
      chatId: chatId,
      direction: direction,
    );
    if (message == null) {
      return null;
    }
    await _ensureMediaDownloadsStarted(message.content);
    return _toPipelineMessage(message);
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int messageId,
    required int targetChatId,
  }) async {
    final selfChatId = await _requireSelfChatId();
    final response = await _transport.send(
      ForwardMessages(
        chatId: targetChatId,
        messageThreadId: 0,
        fromChatId: selfChatId,
        messageIds: [messageId],
        options: null,
        sendCopy: false,
        removeCaption: false,
        onlyPreview: false,
      ),
    );
    final object = _assertNoError(response);
    if (object is! Messages || object.messages.isEmpty) {
      throw StateError('forwardMessages 返回异常，无法提取目标消息 ID');
    }
    final targetMessageId = object.messages.first.id;

    await _sendExpectOk(
      DeleteMessages(chatId: selfChatId, messageIds: [messageId], revoke: true),
    );

    return ClassifyReceipt(
      sourceChatId: selfChatId,
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
    final response = await _transport.send(
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
    );
    final object = _assertNoError(response);
    if (object is! Messages) {
      throw StateError('undo forward 返回非 Messages: ${object.getConstructor()}');
    }
    await _sendExpectOk(
      DeleteMessages(
        chatId: targetChatId,
        messageIds: [targetMessageId],
        revoke: true,
      ),
    );
  }

  Future<void> _loadSelfChatId() async {
    final response = await _transport.send(const GetMe());
    final object = _assertNoError(response);
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
    final response = await _transport.send(
      DownloadFile(
        fileId: file.id,
        priority: priority,
        offset: _downloadOffsetStart,
        limit: _downloadLimitUnlimited,
        synchronous: false,
      ),
    );
    _assertNoError(response);
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
    final response = await _transport.send(
      GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        onlyLocal: false,
      ),
    );
    final object = _assertNoError(response);
    if (object is! Messages) {
      throw StateError('GetChatHistory 返回类型异常: ${object.getConstructor()}');
    }
    return object.messages;
  }

  PipelineMessage _toPipelineMessage(Message message) {
    return PipelineMessage(
      id: message.id,
      preview: mapMessagePreview(message.content),
    );
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

  Future<void> _sendExpectOk(TdFunction function) async {
    final response = await _transport.send(function);
    final object = _assertNoError(response);
    if (object is! Ok) {
      throw StateError('请求返回非 Ok: ${object.getConstructor()}');
    }
  }

  TdObject _assertNoError(TdObject object) {
    if (object is TdError) {
      throw TdlibRequestException(code: object.code, message: object.message);
    }
    return object;
  }

  void _handleUpdate(TdObject update) {
    if (update is UpdateAuthorizationState) {
      _authStateController.add(update.authorizationState);
      _handleAuthTransition(update.authorizationState);
      return;
    }
    if (update is UpdateConnectionState) {
      _connectionController.add(update.state);
    }
  }

  void _handleAuthTransition(AuthorizationState state) {
    if (state is! AuthorizationStateWaitTdlibParameters) {
      return;
    }
    unawaited(_configureTdlib());
  }

  Future<void> _configureTdlib() async {
    final baseDir = await getApplicationSupportDirectory();
    final dbDir = Directory('${baseDir.path}/tgsorter/tdlib/db');
    final filesDir = Directory('${baseDir.path}/tgsorter/tdlib/files');
    await dbDir.create(recursive: true);
    await filesDir.create(recursive: true);

    await _sendExpectOk(
      const SetLogVerbosityLevel(newVerbosityLevel: _tdLogVerbosityLevel),
    );
    await _sendExpectOk(
      SetTdlibParameters(
        useTestDc: false,
        databaseDirectory: dbDir.path,
        filesDirectory: filesDir.path,
        databaseEncryptionKey: '',
        useFileDatabase: true,
        useChatInfoDatabase: true,
        useMessageDatabase: true,
        useSecretChats: false,
        apiId: _credentials.apiId,
        apiHash: _credentials.apiHash,
        systemLanguageCode: 'zh-hans',
        deviceModel: 'Flutter ${Platform.operatingSystem}',
        systemVersion: Platform.operatingSystemVersion,
        applicationVersion: '1.0.0',
        enableStorageOptimizer: true,
        ignoreFileNames: false,
      ),
    );
  }
}
