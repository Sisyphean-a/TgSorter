import 'package:tgsorter/app/models/category_config.dart';

class AppSettings {
  const AppSettings({required this.categories});

  final List<CategoryConfig> categories;

  static AppSettings defaults() {
    return const AppSettings(
      categories: [
        CategoryConfig(key: 'a', name: '分类 A', targetChatId: null),
        CategoryConfig(key: 'b', name: '分类 B', targetChatId: null),
        CategoryConfig(key: 'c', name: '分类 C', targetChatId: null),
      ],
    );
  }

  AppSettings updateCategory(CategoryConfig config) {
    final updated = categories
        .map((item) => item.key == config.key ? config : item)
        .toList(growable: false);
    return AppSettings(categories: updated);
  }
}
