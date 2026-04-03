import 'package:tgsorter/app/models/pipeline_message.dart';

import 'media_gateway.dart';
import 'message_read_gateway.dart';

class PipelineMediaRefreshService {
  PipelineMediaRefreshService({
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
}
