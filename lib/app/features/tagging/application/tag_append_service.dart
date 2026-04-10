import 'package:tgsorter/app/models/tag_config.dart';

class TagAppendService {
  const TagAppendService();

  TagAppendResult appendTag(String currentText, String rawTag) {
    final tag = TagConfig.fromRaw(rawTag).displayName;
    if (_hasExactTag(currentText, tag)) {
      return TagAppendResult(text: currentText, changed: false);
    }
    final trimmed = currentText.trimRight();
    if (trimmed.isEmpty) {
      return TagAppendResult(text: tag, changed: true);
    }
    return TagAppendResult(text: '$trimmed $tag', changed: true);
  }

  bool _hasExactTag(String text, String tag) {
    final escaped = RegExp.escape(tag);
    final pattern = RegExp('(^|\\s)$escaped(?=\\s|\$)');
    return pattern.hasMatch(text);
  }
}

class TagAppendResult {
  const TagAppendResult({required this.text, required this.changed});

  final String text;
  final bool changed;
}
