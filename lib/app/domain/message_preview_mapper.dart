import 'package:tdlib/td_api.dart';

enum MessagePreviewKind { text, photo, unsupported }

class MessagePreview {
  const MessagePreview({
    required this.kind,
    required this.title,
    this.subtitle,
    this.localImagePath,
  });

  final MessagePreviewKind kind;
  final String title;
  final String? subtitle;
  final String? localImagePath;
}

MessagePreview mapMessagePreview(MessageContent content) {
  if (content is MessageText) {
    return MessagePreview(
      kind: MessagePreviewKind.text,
      title: content.text.text,
    );
  }

  if (content is MessagePhoto) {
    final caption = content.caption.text.trim();
    final path = _resolvePhotoPath(content.photo.sizes);
    return MessagePreview(
      kind: MessagePreviewKind.photo,
      title: caption.isEmpty ? '[图片]' : caption,
      localImagePath: path,
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
