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
    final resolvedMessage = await _resolveLinkPreview(message);
    final preview = resolvedMessage.content.linkPreview;
    if (preview == null || _hasPreviewImage(preview)) {
      return resolvedMessage;
    }
    final url = preview.url.trim();
    if (url.isEmpty) {
      return resolvedMessage;
    }
    final instantImageUrl = await _loadFirstInstantImageUrl(url);
    if (instantImageUrl == null) {
      return resolvedMessage;
    }
    return _withLinkPreview(
      resolvedMessage,
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

  Future<TdMessageDto> _resolveLinkPreview(TdMessageDto message) async {
    if (message.content.linkPreview != null) {
      return message;
    }
    final capabilities = _adapter.capabilities;
    if (capabilities != null && !capabilities.supportsGetWebPagePreview) {
      return message;
    }
    final text = message.content.text;
    if (message.content.kind != TdMessageContentKind.text ||
        text == null ||
        !_hasResolvableLink(text)) {
      return message;
    }
    final preview = await _loadWebPagePreview(text);
    if (preview == null) {
      return message;
    }
    return _withLinkPreview(message, preview);
  }

  Future<TdLinkPreviewDto?> _loadWebPagePreview(TdFormattedTextDto text) async {
    try {
      final envelope = await _adapter.sendWire(
        GetWebPagePreview(text: _toTdFormattedText(text)),
        request: 'getWebPagePreview',
        phase: TdlibPhase.business,
      );
      return TdMessageDto.parseLegacyWebPagePreview(envelope.payload);
    } on TdlibFailure catch (error) {
      if (error.code == 404) {
        return null;
      }
      if (_isUnsupportedFunctionError(error, 'getWebPagePreview')) {
        return null;
      }
      rethrow;
    }
  }

  FormattedText _toTdFormattedText(TdFormattedTextDto text) {
    return FormattedText(
      text: text.text,
      entities: text.entities
          .map(_toTdTextEntity)
          .nonNulls
          .toList(growable: false),
    );
  }

  TextEntity? _toTdTextEntity(TdTextEntityDto entity) {
    final type = _toTdTextEntityType(entity);
    if (type == null) {
      return null;
    }
    return TextEntity(offset: entity.offset, length: entity.length, type: type);
  }

  TextEntityType? _toTdTextEntityType(TdTextEntityDto entity) {
    switch (entity.kind) {
      case TdTextEntityKind.url:
        return const TextEntityTypeUrl();
      case TdTextEntityKind.textUrl:
        final url = entity.url?.trim() ?? '';
        if (url.isEmpty) {
          return null;
        }
        return TextEntityTypeTextUrl(url: url);
      case TdTextEntityKind.emailAddress:
        return const TextEntityTypeEmailAddress();
      case TdTextEntityKind.phoneNumber:
        return const TextEntityTypePhoneNumber();
      case TdTextEntityKind.other:
        return null;
    }
  }

  bool _hasResolvableLink(TdFormattedTextDto text) {
    for (final entity in text.entities) {
      if (entity.kind == TdTextEntityKind.url ||
          entity.kind == TdTextEntityKind.textUrl) {
        return true;
      }
    }
    return false;
  }

  bool _isUnsupportedFunctionError(TdlibFailure error, String constructor) {
    return error.code == 400 &&
        error.message.contains('Unknown class "$constructor"');
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
      hasEditabilityFlag: message.hasEditabilityFlag,
      isOutgoing: message.isOutgoing,
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
