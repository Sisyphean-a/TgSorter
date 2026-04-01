import 'package:tgsorter/app/services/td_message_dto.dart';

enum MessagePreviewKind { text, photo, video, audio, unsupported }

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

  return const MessagePreview(
    kind: MessagePreviewKind.unsupported,
    title: '[暂不支持预览的消息类型，请直接分类]',
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
