import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/media_preparation_service.dart';
import 'package:tgsorter/app/services/media_download_coordinator.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/telegram_message_reader.dart';

class TelegramMediaService implements MediaPreparationService {
  TelegramMediaService({
    required TdlibAdapter adapter,
    required TelegramMessageReader reader,
    MediaDownloadCoordinator? mediaDownloadCoordinator,
  }) : _reader = reader,
       _mediaDownloadCoordinator =
           mediaDownloadCoordinator ??
           MediaDownloadCoordinator(adapter: adapter);

  final TelegramMessageReader _reader;
  final MediaDownloadCoordinator _mediaDownloadCoordinator;

  @override
  Future<MediaPreparationResult> preparePlayback(MediaHandle handle) async {
    final message = await prepareMediaPlayback(
      sourceChatId: handle.sourceChatId,
      messageId: handle.itemMessageId,
    );
    final playbackPath = _resolvePlaybackPath(message, handle.kind);
    return MediaPreparationResult(
      status: _statusFor(playbackPath),
      previewPath: _resolvePreviewPath(message, handle.kind),
      playbackPath: playbackPath,
    );
  }

  @override
  Future<MediaPreparationResult> preparePreview(MediaHandle handle) async {
    await prepareMediaPreview(
      sourceChatId: handle.sourceChatId,
      messageId: handle.itemMessageId,
    );
    final message = await _reader.refreshMessage(
      sourceChatId: handle.sourceChatId,
      messageId: handle.itemMessageId,
    );
    final previewPath = _resolvePreviewPath(message, handle.kind);
    return MediaPreparationResult(
      status: _statusFor(previewPath),
      previewPath: previewPath,
      playbackPath: _resolvePlaybackPath(message, handle.kind),
    );
  }

  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    final message = await _reader.loadMessage(sourceChatId, messageId);
    final content = message.content;
    await _mediaDownloadCoordinator.preparePlayback(content);
    if (!_shouldRefreshAfterPrepare(content)) {
      return _reader.toPipelineMessage(
        message: message,
        sourceChatId: sourceChatId,
      );
    }
    // 音视频下载启动后需要重新读取消息，拿到最新本地路径。
    return _reader.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
  }

  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {
    final message = await _reader.loadMessage(sourceChatId, messageId);
    await _mediaDownloadCoordinator.warmUpPreview(message.content);
  }

  bool _shouldRefreshAfterPrepare(TdMessageContentDto content) {
    return content.kind == TdMessageContentKind.audio ||
        content.kind == TdMessageContentKind.video;
  }

  String? _resolvePreviewPath(PipelineMessage message, MediaItemKind kind) {
    final preview = message.preview;
    if (preview.mediaItems.isNotEmpty) {
      final item = preview.mediaItems.firstWhere(
        (candidate) => candidate.kind == kind,
        orElse: () => preview.mediaItems.first,
      );
      return item.previewPath ?? item.fullPath;
    }
    if (kind == MediaItemKind.video) {
      return preview.localVideoThumbnailPath ?? preview.localVideoPath;
    }
    return preview.localImagePath;
  }

  String? _resolvePlaybackPath(PipelineMessage message, MediaItemKind kind) {
    final preview = message.preview;
    if (preview.mediaItems.isNotEmpty) {
      final item = preview.mediaItems.firstWhere(
        (candidate) => candidate.kind == kind,
        orElse: () => preview.mediaItems.first,
      );
      return item.fullPath ?? item.previewPath;
    }
    if (kind == MediaItemKind.video) {
      return preview.localVideoPath;
    }
    return preview.localImagePath;
  }

  MediaPreparationStatus _statusFor(String? path) {
    return path != null && path.isNotEmpty
        ? MediaPreparationStatus.ready
        : MediaPreparationStatus.unavailable;
  }
}
