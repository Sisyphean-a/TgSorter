import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

import '../ports/classify_gateway.dart';
import '../ports/media_gateway.dart';
import '../ports/message_read_gateway.dart';
import '../ports/recovery_gateway.dart';

class TelegramClassifyGatewayAdapter implements ClassifyGateway {
  const TelegramClassifyGatewayAdapter(this._gateway);

  final ClassifyGateway _gateway;

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) {
    return _gateway.classifyMessage(
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
    return _gateway.undoClassify(
      sourceChatId: sourceChatId,
      targetChatId: targetChatId,
      targetMessageIds: targetMessageIds,
    );
  }
}

class TelegramMediaGatewayAdapter implements MediaGateway {
  const TelegramMediaGatewayAdapter(this._gateway);

  final MediaGateway _gateway;

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) {
    return _gateway.prepareMediaPreview(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    return _gateway.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}

class TelegramMessageReadGatewayAdapter implements MessageReadGateway {
  const TelegramMessageReadGatewayAdapter(this._gateway);

  final MessageReadGateway _gateway;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) {
    return _gateway.countRemainingMessages(sourceChatId: sourceChatId);
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) {
    return _gateway.fetchMessagePage(
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
    return _gateway.fetchNextMessage(
      direction: direction,
      sourceChatId: sourceChatId,
    );
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) {
    return _gateway.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}

class TelegramRecoveryGatewayAdapter implements RecoveryGateway {
  const TelegramRecoveryGatewayAdapter(this._gateway);

  final RecoveryGateway _gateway;

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    return _gateway.recoverPendingClassifyOperations();
  }
}
