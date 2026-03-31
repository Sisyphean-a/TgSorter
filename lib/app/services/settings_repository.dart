import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _namePrefix = 'category_name_';
  static const _chatIdPrefix = 'category_chat_id_';
  static const _fetchDirectionKey = 'message_fetch_direction';
  static const _fetchDirectionLatest = 'latest_first';
  static const _fetchDirectionOldest = 'oldest_first';

  AppSettings load() {
    var settings = AppSettings.defaults();
    final fetchDirectionRaw = _prefs.getString(_fetchDirectionKey);
    final fetchDirection = _parseFetchDirection(fetchDirectionRaw);
    settings = settings.updateFetchDirection(fetchDirection);
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
    await _prefs.setString(
      _fetchDirectionKey,
      _encodeFetchDirection(settings.fetchDirection),
    );
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

  MessageFetchDirection _parseFetchDirection(String? raw) {
    if (raw == _fetchDirectionOldest) {
      return MessageFetchDirection.oldestFirst;
    }
    return MessageFetchDirection.latestFirst;
  }

  String _encodeFetchDirection(MessageFetchDirection direction) {
    if (direction == MessageFetchDirection.oldestFirst) {
      return _fetchDirectionOldest;
    }
    return _fetchDirectionLatest;
  }
}
