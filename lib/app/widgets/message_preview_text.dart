import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:url_launcher/url_launcher.dart';

class MessagePreviewText extends StatefulWidget {
  const MessagePreviewText({
    super.key,
    required this.text,
    required this.fallbackText,
    required this.fontSize,
  });

  final TdFormattedTextDto? text;
  final String fallbackText;
  final double fontSize;

  @override
  State<MessagePreviewText> createState() => _MessagePreviewTextState();
}

class _MessagePreviewTextState extends State<MessagePreviewText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final text = widget.text;
    if (text == null || text.entities.isEmpty) {
      return Text(
        widget.fallbackText,
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: _buildSpans(context, text),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, TdFormattedTextDto text) {
    final spans = <InlineSpan>[];
    final entities = [...text.entities]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    var cursor = 0;
    for (final entity in entities) {
      if (entity.length <= 0 ||
          entity.offset < cursor ||
          entity.offset > text.text.length) {
        continue;
      }
      if (entity.offset > cursor) {
        spans.add(TextSpan(text: text.text.substring(cursor, entity.offset)));
      }
      final end = (entity.offset + entity.length).clamp(
        entity.offset,
        text.text.length,
      );
      final entityText = text.text.substring(entity.offset, end);
      spans.add(_buildEntitySpan(context, entity, entityText));
      cursor = end;
    }
    if (cursor < text.text.length) {
      spans.add(TextSpan(text: text.text.substring(cursor)));
    }
    return spans;
  }

  TextSpan _buildEntitySpan(
    BuildContext context,
    TdTextEntityDto entity,
    String entityText,
  ) {
    final link = _toLink(entity, entityText);
    if (link == null) {
      return TextSpan(text: entityText);
    }
    final recognizer = TapGestureRecognizer()
      ..onTap = () => _openLink(context, link);
    _recognizers.add(recognizer);
    return TextSpan(
      text: entityText,
      style: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      recognizer: recognizer,
    );
  }

  String? _toLink(TdTextEntityDto entity, String text) {
    if (entity.kind == TdTextEntityKind.textUrl) {
      return entity.url;
    }
    if (entity.kind == TdTextEntityKind.url) {
      return text;
    }
    if (entity.kind == TdTextEntityKind.emailAddress) {
      return 'mailto:$text';
    }
    if (entity.kind == TdTextEntityKind.phoneNumber) {
      return 'tel:$text';
    }
    return null;
  }

  Future<void> _openLink(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接打开失败')));
    }
  }

  void _disposeRecognizers() {
    for (final item in _recognizers) {
      item.dispose();
    }
    _recognizers.clear();
  }
}
