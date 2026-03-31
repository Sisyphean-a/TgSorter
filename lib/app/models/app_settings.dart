import 'package:tgsorter/app/models/category_config.dart';

enum MessageFetchDirection { latestFirst, oldestFirst }

class AppSettings {
  const AppSettings({required this.categories, required this.fetchDirection});

  final List<CategoryConfig> categories;
  final MessageFetchDirection fetchDirection;

  static AppSettings defaults() {
    return const AppSettings(
      categories: [
        CategoryConfig(key: 'a', name: '分类 A', targetChatId: null),
        CategoryConfig(key: 'b', name: '分类 B', targetChatId: null),
        CategoryConfig(key: 'c', name: '分类 C', targetChatId: null),
      ],
      fetchDirection: MessageFetchDirection.latestFirst,
    );
  }

  AppSettings updateCategory(CategoryConfig config) {
    final updated = categories
        .map((item) => item.key == config.key ? config : item)
        .toList(growable: false);
    return AppSettings(categories: updated, fetchDirection: fetchDirection);
  }

  AppSettings updateFetchDirection(MessageFetchDirection direction) {
    return AppSettings(categories: categories, fetchDirection: direction);
  }
}
