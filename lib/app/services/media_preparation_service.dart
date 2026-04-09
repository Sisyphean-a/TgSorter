import 'package:tgsorter/app/domain/message_preview_mapper.dart';

enum MediaPreparationStatus { ready, unavailable, failed }

class MediaHandle {
  const MediaHandle({
    required this.sourceChatId,
    required this.itemMessageId,
    required this.kind,
  });

  final int sourceChatId;
  final int itemMessageId;
  final MediaItemKind kind;
}

class MediaPreparationResult {
  const MediaPreparationResult({
    required this.status,
    this.previewPath,
    this.playbackPath,
    this.message,
  });

  final MediaPreparationStatus status;
  final String? previewPath;
  final String? playbackPath;
  final String? message;
}

abstract interface class MediaPreparationService {
  Future<MediaPreparationResult> preparePreview(MediaHandle handle);

  Future<MediaPreparationResult> preparePlayback(MediaHandle handle);
}
