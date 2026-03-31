import 'package:tdlib/td_api.dart';

enum MessagePreviewKind { text, photo, video, unsupported }

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
  });

  final MessagePreviewKind kind;
  final String title;
  final String? subtitle;
  final FormattedText? text;
  final String? localImagePath;
  final String? localVideoPath;
  final String? localVideoThumbnailPath;
  final int? videoDurationSeconds;
}

MessagePreview mapMessagePreview(MessageContent content) {
  if (content is MessageText) {
    return MessagePreview(
      kind: MessagePreviewKind.text,
      title: content.text.text,
      text: content.text,
    );
  }

  if (content is MessagePhoto) {
    final caption = content.caption.text.trim();
    final path = _resolvePhotoPath(content.photo.sizes);
    return MessagePreview(
      kind: MessagePreviewKind.photo,
      title: caption.isEmpty ? '[图片]' : caption,
      text: content.caption,
      localImagePath: path,
    );
  }

  if (content is MessageVideo) {
    final caption = content.caption.text.trim();
    return MessagePreview(
      kind: MessagePreviewKind.video,
      title: caption.isEmpty ? '[视频]' : caption,
      text: content.caption,
      localVideoPath: _resolveFilePath(content.video.video),
      localVideoThumbnailPath: _resolveThumbnailPath(content.video.thumbnail),
      videoDurationSeconds: content.video.duration,
    );
  }

  return const MessagePreview(
    kind: MessagePreviewKind.unsupported,
    title: '[暂不支持预览的消息类型，请直接分类]',
  );
}

String? _resolvePhotoPath(List<PhotoSize> sizes) {
  if (sizes.isEmpty) {
    return null;
  }
  final photoFile = sizes.last.photo.local;
  if (!photoFile.isDownloadingCompleted || photoFile.path.isEmpty) {
    return null;
  }
  return photoFile.path;
}

String? _resolveFilePath(File file) {
  final local = file.local;
  if (local.path.isEmpty) {
    return null;
  }
  return local.path;
}

String? _resolveThumbnailPath(Thumbnail? thumbnail) {
  if (thumbnail == null) {
    return null;
  }
  return _resolveFilePath(thumbnail.file);
}
