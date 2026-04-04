import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

/// Pipeline feature 依赖的最小消息读取能力接口（capability port）。
abstract class MessageReadGateway {
  Future<int> countRemainingMessages({required int? sourceChatId});

  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  });

  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  });

  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  });
}

