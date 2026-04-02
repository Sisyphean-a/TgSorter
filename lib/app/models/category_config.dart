class CategoryConfig {
  const CategoryConfig({
    required this.key,
    required this.targetChatId,
    required this.targetChatTitle,
  });

  final String key;
  final int targetChatId;
  final String targetChatTitle;

  CategoryConfig copyWith({int? targetChatId, String? targetChatTitle}) {
    return CategoryConfig(
      key: key,
      targetChatId: targetChatId ?? this.targetChatId,
      targetChatTitle: targetChatTitle ?? this.targetChatTitle,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CategoryConfig &&
            key == other.key &&
            targetChatId == other.targetChatId &&
            targetChatTitle == other.targetChatTitle;
  }

  @override
  int get hashCode => Object.hash(key, targetChatId, targetChatTitle);
}
