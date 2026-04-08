import 'package:tgsorter/app/services/td_message_dto.dart';

enum MessagePreviewKind { text, photo, video, audio, link, unsupported }
enum MediaItemKind { photo, video }

class MediaItemPreview {
  const MediaItemPreview({
    required this.messageId,
    required this.kind,
    this.width,
    this.height,
    this.previewPath,
    this.fullPath,
    this.previewFileId,
    this.fullFileId,
    this.durationSeconds,
    this.caption,
  });

  final int messageId;
  final MediaItemKind kind;
  final int? width;
  final int? height;
  final String? previewPath;
  final String? fullPath;
  final int? previewFileId;
  final int? fullFileId;
  final int? durationSeconds;
  final TdFormattedTextDto? caption;

  bool get hasReadyPreview =>
      (previewPath != null && previewPath!.isNotEmpty) ||
      (fullPath != null && fullPath!.isNotEmpty);

  double get aspectRatio {
    final safeWidth = width ?? 0;
    final safeHeight = height ?? 0;
    if (safeWidth <= 0 || safeHeight <= 0) {
      return 1;
    }
    return safeWidth / safeHeight;
  }

  MediaItemPreview copyWith({
    int? messageId,
    MediaItemKind? kind,
    int? width,
    int? height,
    String? previewPath,
    String? fullPath,
    int? previewFileId,
    int? fullFileId,
    int? durationSeconds,
    TdFormattedTextDto? caption,
  }) {
    return MediaItemPreview(
      messageId: messageId ?? this.messageId,
      kind: kind ?? this.kind,
      width: width ?? this.width,
      height: height ?? this.height,
      previewPath: previewPath ?? this.previewPath,
      fullPath: fullPath ?? this.fullPath,
      previewFileId: previewFileId ?? this.previewFileId,
      fullFileId: fullFileId ?? this.fullFileId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      caption: caption ?? this.caption,
    );
  }
}

class LinkCardPreview {
  const LinkCardPreview({
    required this.url,
    required this.displayUrl,
    required this.siteName,
    required this.title,
    required this.description,
    this.localImagePath,
    this.remoteImageFileId,
  });

  final String url;
  final String displayUrl;
  final String siteName;
  final String title;
  final String description;
  final String? localImagePath;
  final int? remoteImageFileId;
}

class AudioTrackPreview {
  const AudioTrackPreview({
    required this.messageId,
    required this.title,
    this.subtitle,
    this.localAudioPath,
    this.audioDurationSeconds,
  });

  final int messageId;
  final String title;
  final String? subtitle;
  final String? localAudioPath;
  final int? audioDurationSeconds;

  AudioTrackPreview copyWith({
    int? messageId,
    String? title,
    String? subtitle,
    String? localAudioPath,
    int? audioDurationSeconds,
  }) {
    return AudioTrackPreview(
      messageId: messageId ?? this.messageId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
    );
  }
}

class MessagePreview {
  const MessagePreview({
    required this.kind,
    required this.title,
    this.subtitle,
    this.text,
    this.localImagePath,
    this.localVideoPath,
    this.localVideoThumbnailPath,
    this.videoDurationSeconds,
    this.localAudioPath,
    this.audioDurationSeconds,
    this.audioTracks = const <AudioTrackPreview>[],
    this.mediaItems = const <MediaItemPreview>[],
    this.linkCard,
  });

  final MessagePreviewKind kind;
  final String title;
  final String? subtitle;
  final TdFormattedTextDto? text;
  final String? localImagePath;
  final String? localVideoPath;
  final String? localVideoThumbnailPath;
  final int? videoDurationSeconds;
  final String? localAudioPath;
  final int? audioDurationSeconds;
  final List<AudioTrackPreview> audioTracks;
  final List<MediaItemPreview> mediaItems;
  final LinkCardPreview? linkCard;

  MessagePreview copyWith({
    MessagePreviewKind? kind,
    String? title,
    String? subtitle,
    TdFormattedTextDto? text,
    String? localImagePath,
    String? localVideoPath,
    String? localVideoThumbnailPath,
    int? videoDurationSeconds,
    String? localAudioPath,
    int? audioDurationSeconds,
    List<AudioTrackPreview>? audioTracks,
    List<MediaItemPreview>? mediaItems,
    LinkCardPreview? linkCard,
  }) {
    return MessagePreview(
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      text: text ?? this.text,
      localImagePath: localImagePath ?? this.localImagePath,
      localVideoPath: localVideoPath ?? this.localVideoPath,
      localVideoThumbnailPath:
          localVideoThumbnailPath ?? this.localVideoThumbnailPath,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      localAudioPath: localAudioPath ?? this.localAudioPath,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      audioTracks: audioTracks ?? this.audioTracks,
      mediaItems: mediaItems ?? this.mediaItems,
      linkCard: linkCard ?? this.linkCard,
    );
  }
}

MessagePreview mapMessagePreview(TdMessageContentDto content) {
  if (content.kind == TdMessageContentKind.text) {
    final text = content.text;
    if (text == null) {
      throw StateError('Text message missing formatted text');
    }
    return MessagePreview(
      kind: MessagePreviewKind.text,
      title: text.text,
      text: text,
      linkCard: mapLinkCardPreview(content),
    );
  }

  if (content.kind == TdMessageContentKind.photo) {
    final caption = content.text?.text.trim() ?? '';
    return MessagePreview(
      kind: MessagePreviewKind.photo,
      title: caption.isEmpty ? '[图片]' : caption,
      text: content.text,
      localImagePath: content.localImagePath,
      mediaItems: [
        MediaItemPreview(
          messageId: content.messageId,
          kind: MediaItemKind.photo,
          width: content.mediaWidth,
          height: content.mediaHeight,
          previewPath: content.localImagePath,
          fullPath: content.fullImagePath,
          previewFileId: content.remoteImageFileId,
          fullFileId: content.remoteFullImageFileId,
          caption: content.text,
        ),
      ],
    );
  }

  if (content.kind == TdMessageContentKind.video) {
    final caption = content.text?.text.trim() ?? '';
    return MessagePreview(
      kind: MessagePreviewKind.video,
      title: caption.isEmpty ? '[视频]' : caption,
      text: content.text,
      localVideoPath: content.localVideoPath,
      localVideoThumbnailPath: content.localVideoThumbnailPath,
      videoDurationSeconds: content.videoDurationSeconds,
      mediaItems: [
        MediaItemPreview(
          messageId: content.messageId,
          kind: MediaItemKind.video,
          width: content.mediaWidth,
          height: content.mediaHeight,
          previewPath: content.localVideoThumbnailPath,
          fullPath: content.localVideoPath,
          previewFileId: content.remoteVideoThumbnailFileId,
          fullFileId: content.remoteVideoFileId,
          durationSeconds: content.videoDurationSeconds,
          caption: content.text,
        ),
      ],
    );
  }

  if (content.kind == TdMessageContentKind.audio) {
    final track = mapAudioTrackPreview(content, messageId: content.messageId);
    return MessagePreview(
      kind: MessagePreviewKind.audio,
      title: track.title,
      subtitle: track.subtitle,
      text: content.text,
      localAudioPath: track.localAudioPath,
      audioDurationSeconds: track.audioDurationSeconds,
      audioTracks: [track],
    );
  }

  final fileName = content.fileName?.trim() ?? '';
  return MessagePreview(
    kind: MessagePreviewKind.unsupported,
    title: fileName.isEmpty ? '[暂不支持预览的消息类型，请直接分类]' : fileName,
    text: content.text,
  );
}

LinkCardPreview? mapLinkCardPreview(TdMessageContentDto content) {
  final preview = content.linkPreview;
  if (preview == null) {
    return null;
  }
  final title = preview.title.trim();
  final site = preview.siteName.trim();
  final description = preview.description.trim();
  final url = preview.url.trim();
  final hasImage =
      preview.localImagePath?.trim().isNotEmpty == true ||
      preview.remoteImageFileId != null;
  if (url.isEmpty ||
      (title.isEmpty && site.isEmpty && description.isEmpty && !hasImage)) {
    return null;
  }
  return LinkCardPreview(
    url: url,
    displayUrl: preview.displayUrl.trim(),
    siteName: site,
    title: title,
    description: description,
    localImagePath: preview.localImagePath,
    remoteImageFileId: preview.remoteImageFileId,
  );
}

AudioTrackPreview mapAudioTrackPreview(
  TdMessageContentDto content, {
  required int messageId,
}) {
  final title = content.audioTitle?.trim().isNotEmpty == true
      ? content.audioTitle!.trim()
      : content.fileName?.trim().isNotEmpty == true
      ? content.fileName!.trim()
      : '[音频]';
  final subtitle = content.audioPerformer?.trim().isNotEmpty == true
      ? content.audioPerformer!.trim()
      : null;
  return AudioTrackPreview(
    messageId: messageId,
    title: title,
    subtitle: subtitle,
    localAudioPath: content.localAudioPath,
    audioDurationSeconds: content.audioDurationSeconds,
  );
}
