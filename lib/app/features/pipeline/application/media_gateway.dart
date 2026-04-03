import 'package:tgsorter/app/models/pipeline_message.dart';

abstract class MediaGateway {
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  });

  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  });
}
