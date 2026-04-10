import 'package:tgsorter/app/services/td_message_dto.dart';

enum TagEditKind { text, caption }

class TagEditTarget {
  const TagEditTarget({
    required this.messageId,
    required this.kind,
    required this.currentText,
  });

  final int messageId;
  final TagEditKind kind;
  final String currentText;
}

class TagTargetSelector {
  const TagTargetSelector();

  TagEditTarget select(List<TdMessageDto> messages) {
    final editable = messages.where((item) => item.canBeEdited).toList();
    if (editable.isEmpty) {
      throw StateError('当前消息不可编辑，无法打标');
    }
    if (editable.length == 1) {
      return _targetFor(editable.single);
    }
    return _firstCaptionWithText(editable) ?? _firstCaptionTarget(editable);
  }

  TagEditTarget? _firstCaptionWithText(List<TdMessageDto> messages) {
    for (final message in messages) {
      final target = _captionTargetFor(message);
      if (target != null && target.currentText.trim().isNotEmpty) {
        return target;
      }
    }
    return null;
  }

  TagEditTarget _firstCaptionTarget(List<TdMessageDto> messages) {
    for (final message in messages) {
      final target = _captionTargetFor(message);
      if (target != null) {
        return target;
      }
    }
    throw StateError('当前媒体组没有可编辑的说明文字');
  }

  TagEditTarget _targetFor(TdMessageDto message) {
    if (message.content.kind == TdMessageContentKind.text) {
      return TagEditTarget(
        messageId: message.id,
        kind: TagEditKind.text,
        currentText: message.content.text?.text ?? '',
      );
    }
    final target = _captionTargetFor(message);
    if (target != null) {
      return target;
    }
    throw StateError('当前消息类型不支持打标');
  }

  TagEditTarget? _captionTargetFor(TdMessageDto message) {
    final text = message.content.text;
    if (text == null || message.content.kind == TdMessageContentKind.text) {
      return null;
    }
    return TagEditTarget(
      messageId: message.id,
      kind: TagEditKind.caption,
      currentText: text.text,
    );
  }
}
