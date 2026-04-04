import 'package:tgsorter/app/models/pipeline_message.dart';

/// Pipeline feature 依赖的最小媒体准备能力接口（capability port）。
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

