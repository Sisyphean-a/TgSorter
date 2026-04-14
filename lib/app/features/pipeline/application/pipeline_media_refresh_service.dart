import 'package:tgsorter/app/models/pipeline_message.dart';

import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';

class PipelineMediaRefreshService {
  PipelineMediaRefreshService.legacy({
    required MediaGateway mediaGateway,
    required MessageReadGateway messageGateway,
  }) : _mediaGateway = mediaGateway,
       _messageGateway = messageGateway;

  final MediaGateway _mediaGateway;
  final MessageReadGateway _messageGateway;

  Future<PipelineMessage> prepareCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) async {
    final prepared = await _mediaGateway.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
    return _messageGateway.refreshMessage(
      sourceChatId: prepared.sourceChatId,
      messageId: prepared.id,
    );
  }

  Future<void> prepareCurrentPreview({
    required int sourceChatId,
    required int messageId,
  }) {
    return _mediaGateway.prepareMediaPreview(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  Future<PipelineMessage> refreshCurrentMedia({
    required int sourceChatId,
    required int messageId,
  }) {
    return _messageGateway.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }
}
