class CategoryConfig {
  const CategoryConfig({
    required this.key,
    required this.name,
    required this.targetChatId,
  });

  final String key;
  final String name;
  final int? targetChatId;

  CategoryConfig copyWith({String? name, int? targetChatId}) {
    return CategoryConfig(
      key: key,
      name: name ?? this.name,
      targetChatId: targetChatId ?? this.targetChatId,
    );
  }
}
