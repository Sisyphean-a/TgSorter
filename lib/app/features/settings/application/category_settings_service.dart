import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';

class CategorySettingsService {
  AppSettings addCategory({
    required AppSettings current,
    required SelectableChat chat,
    int Function()? nowMicros,
  }) {
    _assertNoDuplicateChat(current.categories, chat.id);
    final stamp = nowMicros?.call() ?? DateTime.now().microsecondsSinceEpoch;
    return current.addCategory(
      CategoryConfig(
        key: 'cat_$stamp',
        targetChatId: chat.id,
        targetChatTitle: chat.title,
      ),
    );
  }

  AppSettings updateCategory({
    required AppSettings current,
    required String key,
    required SelectableChat chat,
  }) {
    _assertNoDuplicateChat(current.categories, chat.id, exceptKey: key);
    return current.updateCategory(
      CategoryConfig(
        key: key,
        targetChatId: chat.id,
        targetChatTitle: chat.title,
      ),
    );
  }

  AppSettings removeCategory({
    required AppSettings current,
    required String key,
  }) {
    return current.removeCategory(key);
  }

  void _assertNoDuplicateChat(
    List<CategoryConfig> categories,
    int chatId, {
    String? exceptKey,
  }) {
    for (final item in categories) {
      if (item.key == exceptKey) {
        continue;
      }
      if (item.targetChatId == chatId) {
        throw StateError('该群组或频道已经添加过了');
      }
    }
  }
}
