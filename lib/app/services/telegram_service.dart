import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_library_locator.dart';
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
  static const int _chatListLimit = 200;
  static const int _maxSelectableChats = 120;
  static const Duration _authRequestTimeout = Duration(minutes: 2);
  static const Duration _authorizationReadyTimeout = Duration(seconds: 20);
  static const Duration _getMeTimeout = Duration(seconds: 60);
  static const Duration _getChatTimeout = Duration(seconds: 8);
  static const Duration _proxyConfigureTimeout = Duration(seconds: 8);
  static const Duration _proxyStatePropagationDelay = Duration(
    milliseconds: 200,
  );

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
  bool _tdlibConfiguring = false;
  bool _tdlibConfigured = false;
  Completer<void>? _startCompleter;
  Completer<void> _authorizationReady = Completer<void>();

  @override
  Stream<AuthorizationState> get authStates => _authStateController.stream;

  @override
  Stream<ConnectionState> get connectionStates => _connectionController.stream;

  @override
  Future<void> start() async {
    final runningStart = _startCompleter;
    if (runningStart != null) {
      await runningStart.future;
      return;
    }
    final completer = Completer<void>();
    _startCompleter = completer;
    try {
      final libraryPath = resolveTdlibLibraryPath(TdlibRuntimeInfo.current());
      await TdPlugin.initialize(libraryPath);
      await _transport.start();
      _updatesSub ??= _transport.updates.listen(
        _handleUpdate,
        onError: _handleTransportError,
      );
      final state = await _bootstrapAuthorizationState();
      if (state is! AuthorizationStateWaitTdlibParameters) {
        await _configureProxyIfNeeded();
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      _startCompleter = null;
      rethrow;
    }
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) {
    return _sendExpectOk(
      SetAuthenticationPhoneNumber(phoneNumber: phoneNumber),
      timeout: _authRequestTimeout,
    );
  }

  @override
  Future<void> submitCode(String code) {
    return _sendExpectOk(
      CheckAuthenticationCode(code: code),
      timeout: _authRequestTimeout,
    );
  }

  @override
  Future<void> submitPassword(String password) {
    return _sendExpectOk(
      CheckAuthenticationPassword(password: password),
      timeout: _authRequestTimeout,
    );
  }

  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    await _requireAuthorizationReady();
    await _loadChatsMainUntilDone();
    final response = await _transport.send(
      const GetChats(chatList: ChatListMain(), limit: _chatListLimit),
    );
    final object = _assertNoErrorWithContext(
      response,
      requestLabel: 'getChats(main)',
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
      } on TdlibRequestException catch (error) {
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
    final response = await _transport.send(
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
    );
    final object = _assertNoError(response);
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
    final optionResponse = await _transport.send(
      const GetOption(name: 'my_id'),
    );
    final option = _assertNoError(optionResponse);
    if (option is OptionValueInteger && option.value > 0) {
      _selfChatId = option.value;
      return;
    }
    final response = await _transport.sendWithTimeout(
      const GetMe(),
      _getMeTimeout,
    );
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

  PipelineMessage _toPipelineMessage(Message message, int sourceChatId) {
    return PipelineMessage(
      id: message.id,
      sourceChatId: sourceChatId,
      preview: mapMessagePreview(message.content),
    );
  }

  Future<Chat> _loadChat(int chatId) async {
    final response = await _transport.sendWithTimeout(
      GetChat(chatId: chatId),
      _getChatTimeout,
    );
    final object = _assertNoErrorWithContext(
      response,
      requestLabel: 'getChat($chatId)',
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
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final response = await _transport.sendWithTimeout(function, timeout);
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

  Future<void> _sendExpectOkWithContext(
    TdFunction function, {
    required String requestLabel,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final response = await _transport.sendWithTimeout(function, timeout);
    final object = _assertNoErrorWithContext(
      response,
      requestLabel: requestLabel,
    );
    if (object is! Ok) {
      throw StateError('请求返回非 Ok: ${object.getConstructor()}');
    }
  }

  TdObject _assertNoErrorWithContext(
    TdObject object, {
    required String requestLabel,
  }) {
    if (object is! TdError) {
      return object;
    }
    throw TdlibRequestException(
      code: object.code,
      message: '$requestLabel -> ${object.message}',
    );
  }

  void _handleUpdate(TdObject update) {
    if (update is UpdateAuthorizationState) {
      _authStateController.add(update.authorizationState);
      _recordAuthorizationState(update.authorizationState);
      _handleAuthTransition(update.authorizationState);
      return;
    }
    if (update is UpdateConnectionState) {
      _connectionController.add(update.state);
    }
  }

  void _handleTransportError(Object error, StackTrace stack) {
    developer.log(
      'TDLib 传输层异常: $error',
      name: 'TelegramService',
      error: error,
      stackTrace: stack,
    );
    _authStateController.addError(error, stack);
    _connectionController.addError(error, stack);
  }

  void _recordAuthorizationState(AuthorizationState state) {
    if (state is AuthorizationStateReady) {
      if (!_authorizationReady.isCompleted) {
        _authorizationReady.complete();
      }
      return;
    }
    if (state is AuthorizationStateClosed) {
      _authorizationReady = Completer<void>();
      _selfChatId = null;
    }
  }

  void _handleAuthTransition(AuthorizationState state) {
    if (state is! AuthorizationStateWaitTdlibParameters) {
      return;
    }
    if (_tdlibConfiguring || _tdlibConfigured) {
      return;
    }
    _tdlibConfiguring = true;
    unawaited(
      _configureTdlib()
          .then((_) {
            _tdlibConfigured = true;
          })
          .catchError((error, stack) {
            _authStateController.addError(error, stack);
          })
          .whenComplete(() {
            _tdlibConfiguring = false;
          }),
    );
  }

  Future<AuthorizationState> _bootstrapAuthorizationState() async {
    final response = await _transport.send(const GetAuthorizationState());
    final object = _assertNoError(response);
    if (object is! AuthorizationState) {
      throw StateError(
        'GetAuthorizationState 返回类型异常: ${object.getConstructor()}',
      );
    }
    _authStateController.add(object);
    _recordAuthorizationState(object);
    _handleAuthTransition(object);
    return object;
  }

  Future<void> _requireAuthorizationReady() {
    if (_authorizationReady.isCompleted) {
      return Future<void>.value();
    }
    return _authorizationReady.future.timeout(
      _authorizationReadyTimeout,
      onTimeout: () {
        throw StateError('TDLib 授权未就绪，无法执行当前请求');
      },
    );
  }

  Future<void> _configureTdlib() async {
    final baseDir = await getApplicationSupportDirectory();
    final dbDir = Directory('${baseDir.path}/tgsorter/tdlib/db');
    final filesDir = Directory('${baseDir.path}/tgsorter/tdlib/files');
    await dbDir.create(recursive: true);
    await filesDir.create(recursive: true);

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
    await _configureProxyIfNeeded();
  }

  Future<void> _configureProxyIfNeeded() async {
    final server = _credentials.proxyServer;
    final port = _credentials.proxyPort;
    if (server == null || port == null) {
      await _sendExpectOk(const DisableProxy());
      return;
    }
    final request = AddProxy(
      server: server,
      port: port,
      enable: true,
      type: ProxyTypeSocks5(
        username: _credentials.proxyUsername,
        password: _credentials.proxyPassword,
      ),
    );
    developer.log(
      'configureProxy request=${jsonEncode(request.toJson())}',
      name: 'TelegramService',
    );
    var response = await _sendProxyRequestWithTimeout(request);
    if (_isLegacyProxyShapeError(response)) {
      developer.log(
        'configureProxy detected legacy API shape, retrying with proxy object payload',
        name: 'TelegramService',
      );
      await _configureProxyWithCompatRequest(server: server, port: port);
      return;
    } else if (response is TdError && response.code == 408) {
      developer.log(
        'configureProxy first request timed out, retrying with proxy object payload',
        name: 'TelegramService',
      );
      await _configureProxyWithCompatRequest(server: server, port: port);
      return;
    }
    developer.log(
      'configureProxy responseConstructor=${response.getConstructor()} '
      'response=${jsonEncode(response.toJson())}',
      name: 'TelegramService',
    );
    _assertNoError(response);
  }

  bool _isLegacyProxyShapeError(TdObject object) {
    if (object is! TdError) {
      return false;
    }
    if (object.code != 400) {
      return false;
    }
    return object.message == 'Proxy must be non-empty';
  }

  Future<TdObject> _sendProxyRequestWithTimeout(TdFunction request) async {
    try {
      return await _transport.sendWithTimeout(request, _proxyConfigureTimeout);
    } on TimeoutException catch (error) {
      return TdError(
        code: 408,
        message:
            'Proxy configure timeout: ${request.getConstructor()} (${error.message})',
      );
    }
  }

  Future<void> _configureProxyWithCompatRequest({
    required String server,
    required int port,
  }) async {
    final compatRequest = _AddProxyCompatRequest(
      server: server,
      port: port,
      username: _credentials.proxyUsername,
      password: _credentials.proxyPassword,
    );
    developer.log(
      'configureProxy compatRequest=${jsonEncode(compatRequest.toJson())}',
      name: 'TelegramService',
    );
    _transport.sendWithoutResponse(compatRequest);
    await Future<void>.delayed(_proxyStatePropagationDelay);
    final verifyResponse = await _transport.sendWithTimeout(
      const GetProxies(),
      _proxyConfigureTimeout,
    );
    final verifyObject = _assertNoError(verifyResponse);
    if (verifyObject is! Proxies) {
      throw StateError('GetProxies 返回类型异常: ${verifyObject.getConstructor()}');
    }
    final matched = verifyObject.proxies.where(
      (item) => item.server == server && item.port == port && item.isEnabled,
    );
    if (matched.isEmpty) {
      throw TdlibRequestException(
        code: 502,
        message: '代理兼容配置后校验失败，未发现已启用代理 $server:$port',
      );
    }
    developer.log(
      'configureProxy compat verified enabledProxy=$server:$port',
      name: 'TelegramService',
    );
  }
}

class _AddProxyCompatRequest extends TdFunction {
  const _AddProxyCompatRequest({
    required this.server,
    required this.port,
    required this.username,
    required this.password,
  });

  final String server;
  final int port;
  final String username;
  final String password;

  @override
  String getConstructor() => 'addProxy';

  @override
  Map<String, dynamic> toJson([dynamic extra]) {
    return {
      '@type': getConstructor(),
      'proxy': {
        'server': server,
        'port': port,
        'type': {
          '@type': 'proxyTypeSocks5',
          'username': username,
          'password': password,
        },
      },
      'enable': true,
      '@extra': extra,
    };
  }
}
