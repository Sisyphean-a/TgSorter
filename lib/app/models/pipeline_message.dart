import 'package:tgsorter/app/domain/message_preview_mapper.dart';

class PipelineMessage {
  const PipelineMessage({required this.id, required this.preview});

  final int id;
  final MessagePreview preview;
}
