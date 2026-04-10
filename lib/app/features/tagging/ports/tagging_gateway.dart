import 'package:tgsorter/app/models/pipeline_message.dart';

class ApplyTagResult {
  const ApplyTagResult({required this.message, required this.changed});

  final PipelineMessage message;
  final bool changed;
}

abstract class TaggingGateway {
  Future<ApplyTagResult> applyTag({
    required int sourceChatId,
    required List<int> messageIds,
    required String tagName,
  });
}
