import 'dart:developer' as developer;

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_chat_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class TelegramSessionResolver {
  static const int _defaultChatListLimit = 200;
  static const int _defaultMaxSelectableChats = 120;
  static const Duration _defaultGetMeTimeout = Duration(seconds: 60);
  static const Duration _defaultGetChatTimeout = Duration(seconds: 8);
  static const Duration _defaultTimeoutValue = Duration(seconds: 20);

  TelegramSessionResolver({
    required TdlibAdapter adapter,
    int chatListLimit = _defaultChatListLimit,
    int maxSelectableChats = _defaultMaxSelectableChats,
    Duration getMeTimeout = _defaultGetMeTimeout,
    Duration getChatTimeout = _defaultGetChatTimeout,
    Duration defaultTimeout = _defaultTimeoutValue,
  }) : _adapter = adapter,
       _chatListLimit = chatListLimit,
       _maxSelectableChats = maxSelectableChats,
       _getMeTimeout = getMeTimeout,
       _getChatTimeout = getChatTimeout,
       _defaultTimeout = defaultTimeout;

  final TdlibAdapter _adapter;
  final int _chatListLimit;
  final int _maxSelectableChats;
  final Duration _getMeTimeout;
  final Duration _getChatTimeout;
  final Duration _defaultTimeout;

  int? _selfChatId;

  Future<List<SelectableChat>> listSelectableChats() async {
    await _loadChatsMainUntilDone();
    final envelope = await _adapter.sendWire(
      GetChats(chatList: ChatListMain(), limit: _chatListLimit),
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
        name: 'TelegramSessionResolver',
      );
    }
    result.sort((a, b) => a.title.compareTo(b.title));
    return result;
  }

  Future<int> resolveSourceChatId(int? sourceChatId) async {
    if (sourceChatId != null) {
      return sourceChatId;
    }
    return _requireSelfChatId();
  }

  Future<void> _loadChatsMainUntilDone() async {
    while (true) {
      try {
        await _adapter.sendWireExpectOk(
          LoadChats(chatList: ChatListMain(), limit: _chatListLimit),
          request: 'loadChats(main)',
          phase: TdlibPhase.business,
          timeout: _defaultTimeout,
        );
      } on TdlibFailure catch (error) {
        if (error.code == 404) {
          return;
        }
        rethrow;
      }
    }
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

  Future<TdChatDto> _loadChat(int chatId) async {
    final envelope = await _adapter.sendWire(
      GetChat(chatId: chatId),
      request: 'getChat($chatId)',
      phase: TdlibPhase.business,
      timeout: _getChatTimeout,
    );
    return TdChatDto.fromEnvelope(envelope);
  }

  Future<TdChatDto?> _tryLoadChat(int chatId) async {
    try {
      return await _loadChat(chatId);
    } catch (error, stack) {
      developer.log(
        'getChat($chatId) 失败: $error',
        name: 'TelegramSessionResolver',
        error: error,
        stackTrace: stack,
      );
      return null;
    }
  }
}
