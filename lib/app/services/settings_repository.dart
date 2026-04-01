import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _categoryKeysKey = 'category_keys';
  static const _chatIdPrefix = 'category_chat_id_';
  static const _chatTitlePrefix = 'category_chat_title_';
  static const _fetchDirectionKey = 'message_fetch_direction';
  static const _forwardAsCopyKey = 'forward_as_copy';
  static const _sourceChatIdKey = 'source_chat_id';
  static const _fetchDirectionLatest = 'latest_first';
  static const _fetchDirectionOldest = 'oldest_first';
  static const _batchSizeKey = 'pipeline_batch_size';
  static const _throttleMsKey = 'pipeline_throttle_ms';
  static const _shortcutPrefix = 'shortcut_';
  static const _shortcutCtrlPrefix = 'ctrl+';
  static const _defaultBatchSize = 5;
  static const _defaultThrottleMs = 1200;
  static const _proxyServerKey = 'tdlib_proxy_server';
  static const _proxyPortKey = 'tdlib_proxy_port';
  static const _proxyUsernameKey = 'tdlib_proxy_username';
  static const _proxyPasswordKey = 'tdlib_proxy_password';

  AppSettings load() {
    var settings = AppSettings.defaults();
    final fetchDirectionRaw = _prefs.getString(_fetchDirectionKey);
    final fetchDirection = _parseFetchDirection(fetchDirectionRaw);
    settings = settings.updateFetchDirection(fetchDirection);
    settings = settings.updateForwardAsCopy(
      _prefs.getBool(_forwardAsCopyKey) ?? false,
    );
    final sourceChatIdRaw = _prefs.getString(_sourceChatIdKey);
    final sourceChatId = int.tryParse(sourceChatIdRaw ?? '');
    settings = settings.updateSourceChatId(sourceChatId);
    final batchSize = _prefs.getInt(_batchSizeKey) ?? _defaultBatchSize;
    final throttleMs = _prefs.getInt(_throttleMsKey) ?? _defaultThrottleMs;
    settings = settings.updateBatchOptions(
      batchSize: batchSize,
      throttleMs: throttleMs,
    );
    settings = settings.updateProxySettings(_loadProxySettings());
    for (final action in ShortcutAction.values) {
      final raw = _prefs.getString('$_shortcutPrefix${action.name}');
      final parsed = _parseShortcutBinding(action, raw);
      settings = settings.updateShortcutBinding(parsed.action, parsed);
    }
    final categoryKeys = _prefs.getStringList(_categoryKeysKey) ?? const <String>[];
    for (final key in categoryKeys) {
      final chatId = _prefs.getInt('$_chatIdPrefix$key');
      final chatTitle = _prefs.getString('$_chatTitlePrefix$key') ?? '';
      if (chatId == null || chatTitle.trim().isEmpty) {
        continue;
      }
      settings = settings.addCategory(
        CategoryConfig(
          key: key,
          targetChatId: chatId,
          targetChatTitle: chatTitle,
        ),
      );
    }
    return settings;
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(
      _fetchDirectionKey,
      _encodeFetchDirection(settings.fetchDirection),
    );
    await _prefs.setBool(_forwardAsCopyKey, settings.forwardAsCopy);
    final sourceChatId = settings.sourceChatId;
    if (sourceChatId == null) {
      await _prefs.remove(_sourceChatIdKey);
    } else {
      await _prefs.setString(_sourceChatIdKey, sourceChatId.toString());
    }
    for (final entry in settings.shortcutBindings.entries) {
      await _prefs.setString(
        '$_shortcutPrefix${entry.key.name}',
        _encodeShortcutBinding(entry.value),
      );
    }
    await _prefs.setInt(_batchSizeKey, settings.batchSize);
    await _prefs.setInt(_throttleMsKey, settings.throttleMs);
    await _saveProxySettings(settings.proxy);
    await _saveCategories(settings.categories);
  }

  Future<void> _saveCategories(List<CategoryConfig> categories) async {
    final previousKeys = _prefs.getStringList(_categoryKeysKey) ?? const <String>[];
    final nextKeys = categories.map((item) => item.key).toList(growable: false);
    await _prefs.setStringList(_categoryKeysKey, nextKeys);
    for (final key in previousKeys) {
      if (nextKeys.contains(key)) {
        continue;
      }
      await _prefs.remove('$_chatIdPrefix$key');
      await _prefs.remove('$_chatTitlePrefix$key');
    }
    for (final item in categories) {
      await _prefs.setInt('$_chatIdPrefix${item.key}', item.targetChatId);
      await _prefs.setString(
        '$_chatTitlePrefix${item.key}',
        item.targetChatTitle,
      );
    }
  }

  ProxySettings _loadProxySettings() {
    return ProxySettings(
      server: _prefs.getString(_proxyServerKey) ?? '',
      port: _prefs.getInt(_proxyPortKey),
      username: _prefs.getString(_proxyUsernameKey) ?? '',
      password: _prefs.getString(_proxyPasswordKey) ?? '',
    ).sanitize();
  }

  Future<void> _saveProxySettings(ProxySettings proxy) async {
    final sanitized = proxy.sanitize();
    if (sanitized.server.isEmpty) {
      await _prefs.remove(_proxyServerKey);
    } else {
      await _prefs.setString(_proxyServerKey, sanitized.server);
    }
    if (sanitized.port == null) {
      await _prefs.remove(_proxyPortKey);
    } else {
      await _prefs.setInt(_proxyPortKey, sanitized.port!);
    }
    await _prefs.setString(_proxyUsernameKey, sanitized.username);
    await _prefs.setString(_proxyPasswordKey, sanitized.password);
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

  ShortcutBinding _parseShortcutBinding(ShortcutAction action, String? raw) {
    final fallback = AppSettings.defaultShortcutBindings[action]!;
    if (raw == null || raw.trim().isEmpty) {
      return fallback;
    }
    var source = raw.trim();
    var ctrl = false;
    if (source.startsWith(_shortcutCtrlPrefix)) {
      ctrl = true;
      source = source.substring(_shortcutCtrlPrefix.length);
    }
    final trigger = _triggerFromName(source);
    if (trigger == null) {
      return fallback;
    }
    return ShortcutBinding(action: action, trigger: trigger, ctrl: ctrl);
  }

  String _encodeShortcutBinding(ShortcutBinding binding) {
    if (binding.ctrl) {
      return '$_shortcutCtrlPrefix${binding.trigger.name}';
    }
    return binding.trigger.name;
  }

  ShortcutTrigger? _triggerFromName(String value) {
    for (final trigger in ShortcutTrigger.values) {
      if (trigger.name == value) {
        return trigger;
      }
    }
    return null;
  }
}
