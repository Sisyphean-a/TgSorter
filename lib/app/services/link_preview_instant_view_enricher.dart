import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

const _maxBlockSearchDepth = 6;

class LinkPreviewInstantViewEnricher {
  const LinkPreviewInstantViewEnricher({required TdlibAdapter adapter})
    : _adapter = adapter;

  final TdlibAdapter _adapter;

  Future<TdMessageDto> enrich(TdMessageDto message) async {
    final preview = message.content.linkPreview;
    if (preview == null || _hasPreviewImage(preview)) {
      return message;
    }
    final url = preview.url.trim();
    if (url.isEmpty) {
      return message;
    }
    final instantImageUrl = await _loadFirstInstantImageUrl(url);
    if (instantImageUrl == null) {
      return message;
    }
    return _withLinkPreview(
      message,
      TdLinkPreviewDto(
        url: preview.url,
        displayUrl: preview.displayUrl,
        siteName: preview.siteName,
        title: preview.title,
        description: preview.description,
        localImagePath: preview.localImagePath,
        remoteImageFileId: preview.remoteImageFileId,
        remoteImageUrl: instantImageUrl,
      ),
    );
  }

  Future<String?> _loadFirstInstantImageUrl(String url) async {
    try {
      final envelope = await _adapter.sendWire(
        GetWebPageInstantView(url: url, forceFull: true),
        request: 'getWebPageInstantView($url)',
        phase: TdlibPhase.business,
      );
      return _firstPhotoUrl(envelope.payload['page_blocks']);
    } on TdlibFailure catch (error) {
      if (error.code == 404) {
        return null;
      }
      rethrow;
    }
  }

  String? _firstPhotoUrl(Object? raw, [int depth = 0]) {
    if (depth > _maxBlockSearchDepth || raw == null) {
      return null;
    }
    if (raw is List) {
      return _firstPhotoUrlInList(raw, depth);
    }
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    if (raw['@type'] == 'pageBlockPhoto') {
      final url = raw['url']?.toString().trim() ?? '';
      return url.isEmpty ? null : url;
    }
    return _firstPhotoUrl(raw['page_blocks'], depth + 1) ??
        _firstPhotoUrl(raw['cover'], depth + 1);
  }

  String? _firstPhotoUrlInList(List<Object?> blocks, int depth) {
    for (final block in blocks) {
      final url = _firstPhotoUrl(block, depth + 1);
      if (url != null) {
        return url;
      }
    }
    return null;
  }

  bool _hasPreviewImage(TdLinkPreviewDto preview) {
    return preview.localImagePath?.trim().isNotEmpty == true ||
        preview.remoteImageFileId != null ||
        preview.remoteImageUrl?.trim().isNotEmpty == true;
  }

  TdMessageDto _withLinkPreview(
    TdMessageDto message,
    TdLinkPreviewDto linkPreview,
  ) {
    final content = message.content;
    return TdMessageDto(
      id: message.id,
      mediaAlbumId: message.mediaAlbumId,
      canBeEdited: message.canBeEdited,
      content: TdMessageContentDto(
        kind: content.kind,
        messageId: content.messageId,
        text: content.text,
        mediaWidth: content.mediaWidth,
        mediaHeight: content.mediaHeight,
        localImagePath: content.localImagePath,
        localVideoPath: content.localVideoPath,
        localVideoThumbnailPath: content.localVideoThumbnailPath,
        videoDurationSeconds: content.videoDurationSeconds,
        remoteImageFileId: content.remoteImageFileId,
        remoteVideoFileId: content.remoteVideoFileId,
        remoteVideoThumbnailFileId: content.remoteVideoThumbnailFileId,
        localAudioPath: content.localAudioPath,
        remoteAudioFileId: content.remoteAudioFileId,
        audioDurationSeconds: content.audioDurationSeconds,
        fileName: content.fileName,
        audioTitle: content.audioTitle,
        audioPerformer: content.audioPerformer,
        photoSizes: content.photoSizes,
        fullImagePath: content.fullImagePath,
        remoteFullImageFileId: content.remoteFullImageFileId,
        linkPreview: linkPreview,
      ),
    );
  }
}
