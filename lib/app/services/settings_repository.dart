import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _namePrefix = 'category_name_';
  static const _chatIdPrefix = 'category_chat_id_';
  static const _fetchDirectionKey = 'message_fetch_direction';
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
