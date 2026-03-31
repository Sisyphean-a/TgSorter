import 'package:tgsorter/app/domain/message_preview_mapper.dart';

class PipelineMessage {
  const PipelineMessage({
    required this.id,
    required this.sourceChatId,
    required this.preview,
  });

  final int id;
  final int sourceChatId;
  final MessagePreview preview;
}
