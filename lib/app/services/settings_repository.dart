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
  static const _batchSizeKey = 'pipeline_batch_size';
  static const _throttleMsKey = 'pipeline_throttle_ms';
  static const _defaultBatchSize = 5;
  static const _defaultThrottleMs = 1200;

  AppSettings load() {
    var settings = AppSettings.defaults();
    final fetchDirectionRaw = _prefs.getString(_fetchDirectionKey);
    final fetchDirection = _parseFetchDirection(fetchDirectionRaw);
    settings = settings.updateFetchDirection(fetchDirection);
    final batchSize = _prefs.getInt(_batchSizeKey) ?? _defaultBatchSize;
    final throttleMs = _prefs.getInt(_throttleMsKey) ?? _defaultThrottleMs;
    settings = settings.updateBatchOptions(
      batchSize: batchSize,
      throttleMs: throttleMs,
    );
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
    await _prefs.setInt(_batchSizeKey, settings.batchSize);
    await _prefs.setInt(_throttleMsKey, settings.throttleMs);
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
