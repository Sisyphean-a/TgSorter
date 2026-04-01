import 'package:tgsorter/app/domain/message_preview_mapper.dart';

class PipelineMessage {
  const PipelineMessage({
    required this.id,
    required this.messageIds,
    required this.sourceChatId,
    required this.preview,
  });

  final int id;
  final List<int> messageIds;
  final int sourceChatId;
  final MessagePreview preview;

  PipelineMessage copyWith({
    int? id,
    List<int>? messageIds,
    int? sourceChatId,
    MessagePreview? preview,
  }) {
    return PipelineMessage(
      id: id ?? this.id,
      messageIds: messageIds ?? this.messageIds,
      sourceChatId: sourceChatId ?? this.sourceChatId,
      preview: preview ?? this.preview,
    );
  }
}
