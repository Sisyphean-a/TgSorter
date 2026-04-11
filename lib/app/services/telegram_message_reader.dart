import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_builder.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/link_preview_instant_view_enricher.dart';
import 'package:tgsorter/app/services/media_download_coordinator.dart';
import 'package:tgsorter/app/services/message_history_paginator.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class TelegramMessageReader {
  static const int _historyBatchSizeDefault = 100;
  static const Duration _defaultTimeoutValue = Duration(seconds: 20);
  static const int _albumContinuationBatchSize = 20;

  TelegramMessageReader({
    required TdlibAdapter adapter,
    MessageHistoryPaginator? historyPaginator,
    MediaDownloadCoordinator? mediaDownloadCoordinator,
    LinkPreviewInstantViewEnricher? linkPreviewEnricher,
    MessagePreviewBuilder previewBuilder = const MessagePreviewBuilder(),
    Duration defaultTimeout = _defaultTimeoutValue,
    int historyBatchSize = _historyBatchSizeDefault,
  }) : _adapter = adapter,
       _previewBuilder = previewBuilder,
       _historyPaginator =
           historyPaginator ??
           MessageHistoryPaginator(
             adapter: adapter,
             defaultTimeout: defaultTimeout,
             historyBatchSize: historyBatchSize,
           ),
       _mediaDownloadCoordinator =
           mediaDownloadCoordinator ??
           MediaDownloadCoordinator(adapter: adapter),
       _linkPreviewEnricher =
           linkPreviewEnricher ??
           LinkPreviewInstantViewEnricher(adapter: adapter);

  final TdlibAdapter _adapter;
  final MessagePreviewBuilder _previewBuilder;
  final MessageHistoryPaginator _historyPaginator;
  final MediaDownloadCoordinator _mediaDownloadCoordinator;
  final LinkPreviewInstantViewEnricher _linkPreviewEnricher;

  Future<int> countRemainingMessages(int chatId) async {
    return _historyPaginator.countHistoryMessages(chatId);
  }

  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    final messages = await _fetchPageWithTrailingAlbum(
      direction: direction,
      sourceChatId: sourceChatId,
      fromMessageId: fromMessageId,
      limit: limit,
    );
    final preparedMessages = <TdMessageDto>[];
    for (final item in messages) {
      final prepared = await _preparePreview(item);
      preparedMessages.add(prepared);
    }
    return _previewBuilder.groupPipelineMessages(
      messages: preparedMessages,
      sourceChatId: sourceChatId,
      direction: direction,
    );
  }

  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int sourceChatId,
  }) async {
    final message = await _historyPaginator.fetchSavedMessage(
      chatId: sourceChatId,
      direction: direction,
    );
    if (message == null) {
      return null;
    }
    final prepared = await _preparePreview(message);
    return toPipelineMessage(message: prepared, sourceChatId: sourceChatId);
  }

  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    final message = await _preparePreview(
      await loadMessage(sourceChatId, messageId),
    );
    return toPipelineMessage(message: message, sourceChatId: sourceChatId);
  }

  PipelineMessage toPipelineMessage({
    required TdMessageDto message,
    required int sourceChatId,
  }) {
    return _previewBuilder.toPipelineMessage(
      messages: <TdMessageDto>[message],
      sourceChatId: sourceChatId,
    );
  }

  Future<TdMessageDto> loadMessage(int chatId, int messageId) async {
    final envelope = await _adapter.sendWire(
      GetMessage(chatId: chatId, messageId: messageId),
      request: 'getMessage($chatId,$messageId)',
      phase: TdlibPhase.business,
    );
    return TdMessageDto.fromJson(envelope.payload);
  }

  Future<List<TdMessageDto>> _fetchPageWithTrailingAlbum({
    required MessageFetchDirection direction,
    required int sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    final page = await _historyPaginator.fetchSavedMessagePage(
      chatId: sourceChatId,
      direction: direction,
      fromMessageId: fromMessageId,
      limit: limit,
    );
    final trailingAlbumId = _trailingGroupedAlbumId(page);
    if (trailingAlbumId == null) {
      return page;
    }
    final result = page.toList(growable: true);
    final seenIds = result.map((item) => item.id).toSet();
    var cursor = result.last.id;
    while (true) {
      final nextPage = await _historyPaginator.fetchSavedMessagePage(
        chatId: sourceChatId,
        direction: direction,
        fromMessageId: cursor,
        limit: _albumContinuationBatchSize,
      );
      if (nextPage.isEmpty) {
        return result;
      }
      final continuation = <TdMessageDto>[];
      for (final item in nextPage) {
        if (!seenIds.add(item.id)) {
          continue;
        }
        if (!_belongsToGroupedAlbum(item, trailingAlbumId)) {
          result.addAll(continuation);
          return result;
        }
        continuation.add(item);
      }
      if (continuation.isEmpty) {
        return result;
      }
      result.addAll(continuation);
      cursor = continuation.last.id;
    }
  }

  String? _trailingGroupedAlbumId(List<TdMessageDto> messages) {
    if (messages.isEmpty) {
      return null;
    }
    final trailing = messages.last;
    if (!_isGroupedMediaMessage(trailing)) {
      return null;
    }
    return trailing.mediaAlbumId;
  }

  bool _belongsToGroupedAlbum(TdMessageDto message, String albumId) {
    return _isGroupedMediaMessage(message) && message.mediaAlbumId == albumId;
  }

  bool _isGroupedMediaMessage(TdMessageDto message) {
    final kind = message.content.kind;
    return message.mediaAlbumId != null &&
        (kind == TdMessageContentKind.audio ||
            kind == TdMessageContentKind.photo ||
            kind == TdMessageContentKind.video);
  }

  Future<TdMessageDto> _preparePreview(TdMessageDto message) async {
    final prepared = await _linkPreviewEnricher.enrich(message);
    await _mediaDownloadCoordinator.warmUpPreview(prepared.content);
    return prepared;
  }
}
