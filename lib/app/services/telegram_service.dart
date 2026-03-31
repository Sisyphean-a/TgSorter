import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tdlib/td_client.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';

class TdlibRequestException implements Exception {
  TdlibRequestException({required this.code, required this.message});

  final int code;
  final String message;

  @override
  String toString() => 'TDLib 请求失败($code): $message';
}

class TelegramService {
  static const int _downloadPriorityPhotoPreview = 16;
  static const int _downloadOffsetStart = 0;
  static const int _downloadLimitUnlimited = 0;

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

  Stream<AuthorizationState> get authStates => _authStateController.stream;
  Stream<ConnectionState> get connectionStates => _connectionController.stream;

  Future<void> start() async {
    await TdPlugin.initialize();
    await _transport.start();
    _updatesSub ??= _transport.updates.listen(_handleUpdate);
  }

  Future<void> submitPhoneNumber(String phoneNumber) {
    return _sendExpectOk(
      SetAuthenticationPhoneNumber(phoneNumber: phoneNumber),
    );
  }

  Future<void> submitCode(String code) {
    return _sendExpectOk(CheckAuthenticationCode(code: code));
  }

  Future<void> submitPassword(String password) {
    return _sendExpectOk(CheckAuthenticationPassword(password: password));
  }

  Future<PipelineMessage?> fetchNextSavedMessage() async {
    final chatId = await _requireSelfChatId();
    final response = await _transport.send(
      GetChatHistory(
        chatId: chatId,
        fromMessageId: 0,
        offset: 0,
        limit: 1,
        onlyLocal: false,
      ),
    );
    final object = _assertNoError(response);
    if (object is! Messages || object.messages.isEmpty) {
      return null;
    }
    final message = object.messages.first;
    await _ensurePhotoDownloadStarted(message.content);
    return PipelineMessage(
      id: message.id,
      preview: mapMessagePreview(message.content),
    );
  }

  Future<void> classifyMessage({
    required int messageId,
    required int targetChatId,
  }) async {
    final selfChatId = await _requireSelfChatId();
    await _sendExpectOk(
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
    await _sendExpectOk(
      DeleteMessages(chatId: selfChatId, messageIds: [messageId], revoke: true),
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

  Future<void> _ensurePhotoDownloadStarted(MessageContent content) async {
    if (content is! MessagePhoto) {
      return;
    }
    final file = _pickPreviewPhotoFile(content.photo.sizes);
    if (file == null ||
        _isLocalFileReady(file.local) ||
        !file.local.canBeDownloaded) {
      return;
    }
    final response = await _transport.send(
      DownloadFile(
        fileId: file.id,
        priority: _downloadPriorityPhotoPreview,
        offset: _downloadOffsetStart,
        limit: _downloadLimitUnlimited,
        synchronous: false,
      ),
    );
    _assertNoError(response);
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
    unawaited(
      _sendExpectOk(
        SetTdlibParameters(
          useTestDc: false,
          databaseDirectory: 'tgsorter_td_db',
          filesDirectory: 'tgsorter_td_files',
          databaseEncryptionKey: '',
          useFileDatabase: true,
          useChatInfoDatabase: true,
          useMessageDatabase: true,
          useSecretChats: false,
          apiId: _credentials.apiId,
          apiHash: _credentials.apiHash,
          systemLanguageCode: 'zh-hans',
          deviceModel: 'Android',
          systemVersion: '14',
          applicationVersion: '0.1.0',
          enableStorageOptimizer: true,
          ignoreFileNames: false,
        ),
      ),
    );
  }
}
