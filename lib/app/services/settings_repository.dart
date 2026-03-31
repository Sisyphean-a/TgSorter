import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _namePrefix = 'category_name_';
  static const _chatIdPrefix = 'category_chat_id_';

  AppSettings load() {
    var settings = AppSettings.defaults();
    for (final item in settings.categories) {
      final name = _prefs.getString('$_namePrefix${item.key}') ?? item.name;
      final chatIdRaw = _prefs.getString('$_chatIdPrefix${item.key}');
      final chatId = int.tryParse(chatIdRaw ?? '');
      settings = settings.updateCategory(
        CategoryConfig(key: item.key, name: name, targetChatId: chatId),
      );
    }
    return settings;
  }

  Future<void> save(AppSettings settings) async {
    for (final item in settings.categories) {
      await _prefs.setString('$_namePrefix${item.key}', item.name);
      final value = item.targetChatId;
      if (value == null) {
        await _prefs.remove('$_chatIdPrefix${item.key}');
      } else {
        await _prefs.setString('$_chatIdPrefix${item.key}', value.toString());
      }
    }
  }
}
