import 'package:tgsorter/app/services/td_message_dto.dart';

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
  final TdFormattedTextDto? text;
  final String? localImagePath;
  final String? localVideoPath;
  final String? localVideoThumbnailPath;
  final int? videoDurationSeconds;
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
    );
  }

  if (content.kind == TdMessageContentKind.photo) {
    final caption = content.text?.text.trim() ?? '';
    return MessagePreview(
      kind: MessagePreviewKind.photo,
      title: caption.isEmpty ? '[图片]' : caption,
      text: content.text,
      localImagePath: content.localImagePath,
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
    );
  }

  return const MessagePreview(
    kind: MessagePreviewKind.unsupported,
    title: '[暂不支持预览的消息类型，请直接分类]',
  );
}
