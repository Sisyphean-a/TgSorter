import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class MessageHistoryPaginator {
  MessageHistoryPaginator({
    required this._adapter,
    this._defaultTimeout = const Duration(seconds: 20),
    this._historyBatchSize = 100,
  });

  final TdlibAdapter _adapter;
  final Duration _defaultTimeout;
  final int _historyBatchSize;

  Future<TdMessageDto?> fetchSavedMessage({
    required int chatId,
    required MessageFetchDirection direction,
  }) async {
    final page = await fetchSavedMessagePage(
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

  Future<List<TdMessageDto>> fetchSavedMessagePage({
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

  Future<List<TdMessageDto>> fetchAllHistoryMessages(int chatId) async {
    final all = <TdMessageDto>[];
    final seenMessageIds = <int>{};
    var cursor = 0;
    while (true) {
      final page = await _fetchHistoryPage(
        chatId: chatId,
        fromMessageId: cursor,
        limit: _historyBatchSize,
      );
      if (page.isEmpty) {
        return all.reversed.toList(growable: false);
      }
      final nextCursor = page.last.id;
      var appended = 0;
      for (final item in page) {
        if (item.id == cursor) {
          continue;
        }
        if (!seenMessageIds.add(item.id)) {
          continue;
        }
        all.add(item);
        appended++;
      }
      if (nextCursor == cursor || (cursor != 0 && appended == 0)) {
        throw StateError('统计剩余消息时游标未推进，history_id=$cursor');
      }
      cursor = nextCursor;
    }
  }

  Future<int> countHistoryMessages(int chatId) async {
    final seenMessageIds = <int>{};
    var count = 0;
    var cursor = 0;
    while (true) {
      final page = await _fetchHistoryPage(
        chatId: chatId,
        fromMessageId: cursor,
        limit: _historyBatchSize,
      );
      if (page.isEmpty) {
        return count;
      }
      final nextCursor = page.last.id;
      var appended = 0;
      for (final item in page) {
        if (item.id == cursor) {
          continue;
        }
        if (!seenMessageIds.add(item.id)) {
          continue;
        }
        count++;
        appended++;
      }
      if (nextCursor == cursor || (cursor != 0 && appended == 0)) {
        throw StateError('统计剩余消息时游标未推进，history_id=$cursor');
      }
      cursor = nextCursor;
    }
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
    return messages
        .where((item) => item.id != fromMessageId)
        .take(limit)
        .toList(growable: false);
  }

  Future<List<TdMessageDto>> _fetchOldestSavedMessagePage({
    required int chatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    final all = await fetchAllHistoryMessages(chatId);
    final ordered = all;
    if (fromMessageId == null) {
      return ordered.take(limit).toList(growable: false);
    }
    final start = ordered.indexWhere((item) => item.id == fromMessageId);
    if (start < 0) {
      return const [];
    }
    return ordered.skip(start + 1).take(limit).toList(growable: false);
  }

  Stream<Map<String, dynamic>> scanHistory(
    int chatId, {
    required int beforeMessageId,
  }) async* {
    var cursor = beforeMessageId;
    while (true) {
      final envelope = await _fetchHistoryEnvelope(
        chatId: chatId,
        fromMessageId: cursor,
        limit: _historyBatchSize,
      );
      final messages = TdResponseReader.readList(envelope.payload, 'messages');
      if (messages.isEmpty) return;
      var next = cursor;
      for (final value in messages) {
        final message = TdResponseReader.readMap({'message': value}, 'message');
        final id = TdResponseReader.readInt(message, 'id');
        if (id == cursor) continue;
        if (id <= 0 || (next != 0 && id >= next)) {
          throw StateError('会话历史消息顺序异常');
        }
        next = id;
        yield message;
      }
      if (next == cursor) {
        throw StateError('会话历史分页未推进');
      }
      cursor = next;
    }
  }

  Future<List<TdMessageDto>> _fetchHistoryPage({
    required int chatId,
    required int fromMessageId,
    required int limit,
  }) async {
    final envelope = await _fetchHistoryEnvelope(
      chatId: chatId,
      fromMessageId: fromMessageId,
      limit: limit,
    );
    return TdMessagesDto.fromEnvelope(envelope).messages;
  }

  Future<TdWireEnvelope> _fetchHistoryEnvelope({
    required int chatId,
    required int fromMessageId,
    required int limit,
  }) => _adapter.sendWire(
    GetChatHistory(
      chatId: chatId,
      fromMessageId: fromMessageId,
      offset: 0,
      limit: limit,
      onlyLocal: false,
    ),
    request: 'getChatHistory',
    phase: TdlibPhase.business,
    timeout: _defaultTimeout,
  );
}
