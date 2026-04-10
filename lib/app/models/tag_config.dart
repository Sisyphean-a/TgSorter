class TagConfig {
  const TagConfig({required this.name});

  factory TagConfig.fromRaw(String raw) {
    return TagConfig(name: normalizeName(raw));
  }

  final String name;

  String get displayName => '#$name';

  static String normalizeName(String raw) {
    var value = raw.trim();
    while (value.startsWith('#')) {
      value = value.substring(1).trim();
    }
    if (value.isEmpty) {
      throw ArgumentError.value(raw, 'raw', '标签不能为空');
    }
    if (value.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(raw, 'raw', '标签不能包含空白字符');
    }
    return value;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TagConfig && name == other.name;
  }

  @override
  int get hashCode => name.hashCode;
}

class TagGroupConfig {
  const TagGroupConfig({
    required this.key,
    required this.title,
    required this.tags,
  });

  factory TagGroupConfig.fromRaw({
    required String key,
    required String title,
    required List<String> tags,
  }) {
    final parsed = tags.map(TagConfig.fromRaw).toList(growable: false);
    _assertNoDuplicateTags(parsed);
    return TagGroupConfig(key: key, title: title, tags: parsed);
  }

  static const defaultGroupKey = 'default';
  static const defaultGroupTitle = '默认组';

  final String key;
  final String title;
  final List<TagConfig> tags;

  static const TagGroupConfig emptyDefault = TagGroupConfig(
    key: defaultGroupKey,
    title: defaultGroupTitle,
    tags: <TagConfig>[],
  );

  TagGroupConfig copyWith({String? key, String? title, List<TagConfig>? tags}) {
    final nextTags = tags ?? this.tags;
    _assertNoDuplicateTags(nextTags);
    return TagGroupConfig(
      key: key ?? this.key,
      title: title ?? this.title,
      tags: List<TagConfig>.unmodifiable(nextTags),
    );
  }

  static void _assertNoDuplicateTags(List<TagConfig> tags) {
    final names = <String>{};
    for (final tag in tags) {
      if (!names.add(tag.name)) {
        throw StateError('标签已存在：${tag.displayName}');
      }
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TagGroupConfig &&
            key == other.key &&
            title == other.title &&
            _listEquals(tags, other.tags);
  }

  @override
  int get hashCode => Object.hash(key, title, Object.hashAll(tags));

  bool _listEquals(List<TagConfig> left, List<TagConfig> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
