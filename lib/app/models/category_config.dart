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
}
