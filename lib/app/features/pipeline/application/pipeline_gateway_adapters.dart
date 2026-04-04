import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

import 'classify_gateway.dart';
import 'media_gateway.dart';
import 'message_read_gateway.dart';
import 'recovery_gateway.dart';

class TelegramClassifyGatewayAdapter implements ClassifyGateway {
  const TelegramClassifyGatewayAdapter(this._service);

  final TelegramGateway _service;

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) {
    return _service.classifyMessage(
      sourceChatId: sourceChatId,
      messageIds: messageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
    );
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) {
    return _service.undoClassify(
      sourceChatId: sourceChatId,
      targetChatId: targetChatId,
      targetMessageIds: targetMessageIds,
    );
  }
}

class TelegramMediaGatewayAdapter implements MediaGateway {
  const TelegramMediaGatewayAdapter(this._service);

  final TelegramGateway _service;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) {
    return _service.prepareMediaPreview(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    return _service.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}

class TelegramMessageReadGatewayAdapter implements MessageReadGateway {
  const TelegramMessageReadGatewayAdapter(this._service);

  final TelegramGateway _service;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    return _service.countRemainingMessages(sourceChatId: sourceChatId);
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) {
    return _service.fetchMessagePage(
      direction: direction,
      sourceChatId: sourceChatId,
      fromMessageId: fromMessageId,
      limit: limit,
    );
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) {
    return _service.fetchNextMessage(
      direction: direction,
      sourceChatId: sourceChatId,
    );
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    return _service.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}

class TelegramRecoveryGatewayAdapter implements RecoveryGateway {
  const TelegramRecoveryGatewayAdapter(this._service);

  final RecoverableClassifyGateway _service;

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    return _service.recoverPendingClassifyOperations();
  }
}
