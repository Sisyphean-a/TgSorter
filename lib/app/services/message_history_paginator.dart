import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class MessageHistoryPaginator {
  MessageHistoryPaginator({
    required TdlibAdapter adapter,
    Duration defaultTimeout = const Duration(seconds: 20),
    int historyBatchSize = 100,
  }) : _adapter = adapter,
       _defaultTimeout = defaultTimeout,
       _historyBatchSize = historyBatchSize;

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
      timeout: _defaultTimeout,
    );
    return TdMessagesDto.fromEnvelope(envelope).messages;
  }
}
