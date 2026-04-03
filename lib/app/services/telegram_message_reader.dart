import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_builder.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/media_download_coordinator.dart';
import 'package:tgsorter/app/services/message_history_paginator.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class TelegramMessageReader {
  static const int _historyBatchSizeDefault = 100;
  static const Duration _defaultTimeoutValue = Duration(seconds: 20);

  TelegramMessageReader({
    required TdlibAdapter adapter,
    MessageHistoryPaginator? historyPaginator,
    MediaDownloadCoordinator? mediaDownloadCoordinator,
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
           MediaDownloadCoordinator(adapter: adapter);

  final TdlibAdapter _adapter;
  final MessagePreviewBuilder _previewBuilder;
  final MessageHistoryPaginator _historyPaginator;
  final MediaDownloadCoordinator _mediaDownloadCoordinator;

  Future<int> countRemainingMessages(int chatId) async {
    return _historyPaginator.countHistoryMessages(chatId);
  }

  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    final messages = await _historyPaginator.fetchSavedMessagePage(
      chatId: sourceChatId,
      direction: direction,
      fromMessageId: fromMessageId,
      limit: limit,
    );
    for (final item in messages) {
      await _mediaDownloadCoordinator.warmUpPreview(item.content);
    }
    return _previewBuilder.groupPipelineMessages(
      messages: messages,
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
    await _mediaDownloadCoordinator.warmUpPreview(message.content);
    return toPipelineMessage(message: message, sourceChatId: sourceChatId);
  }

  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    final message = await loadMessage(sourceChatId, messageId);
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
}
