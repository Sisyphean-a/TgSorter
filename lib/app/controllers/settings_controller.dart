import 'package:get/get.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class SettingsController extends GetxController {
  SettingsController(this._repository, this._telegram);

  final SettingsRepository _repository;
  final TelegramGateway _telegram;
  final Rx<AppSettings> settings = AppSettings.defaults().obs;
  final chats = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final chatsError = RxnString();

  @override
  void onInit() {
    super.onInit();
    settings.value = _repository.load();
  }

  CategoryConfig getCategory(String key) {
    return settings.value.categories.firstWhere((item) => item.key == key);
  }

  Future<void> addCategory(SelectableChat chat) async {
    _assertNoDuplicateChat(chat.id);
    final updated = settings.value.addCategory(
      CategoryConfig(
        key: _buildCategoryKey(),
        targetChatId: chat.id,
        targetChatTitle: chat.title,
      ),
    );
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> updateCategoryTarget({
    required String key,
    required SelectableChat chat,
  }) async {
    _assertNoDuplicateChat(chat.id, exceptKey: key);
    final updated = settings.value.updateCategory(
      CategoryConfig(
        key: key,
        targetChatId: chat.id,
        targetChatTitle: chat.title,
      ),
    );
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> removeCategory(String key) async {
    final updated = settings.value.removeCategory(key);
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> saveSourceChat(int? sourceChatId) async {
    final updated = settings.value.updateSourceChatId(sourceChatId);
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> loadChats() async {
    chatsLoading.value = true;
    chatsError.value = null;
    try {
      final loaded = await _telegram.listSelectableChats();
      chats.assignAll(loaded);
    } catch (error) {
      chatsError.value = error.toString();
      rethrow;
    } finally {
      chatsLoading.value = false;
    }
  }

  Future<void> saveFetchDirection(MessageFetchDirection direction) async {
    final updated = settings.value.updateFetchDirection(direction);
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> saveBatchOptions({
    required int batchSize,
    required int throttleMs,
  }) async {
    final safeBatchSize = batchSize < 1 ? 1 : batchSize;
    final safeThrottleMs = throttleMs < 0 ? 0 : throttleMs;
    final updated = settings.value.updateBatchOptions(
      batchSize: safeBatchSize,
      throttleMs: safeThrottleMs,
    );
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> saveProxySettings({
    required String server,
    required String port,
    required String username,
    required String password,
    bool restart = false,
  }) async {
    final updated = settings.value.updateProxySettings(
      ProxySettings(
        server: server,
        port: int.tryParse(port.trim()),
        username: username,
        password: password,
      ),
    );
    settings.value = updated;
    await _repository.save(updated);
    if (!restart) {
      return;
    }
    await _telegram.restart();
  }

  Future<void> saveShortcutBinding({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) async {
    _assertNoConflict(action: action, trigger: trigger, ctrl: ctrl);
    final updated = settings.value.updateShortcutBinding(
      action,
      ShortcutBinding(action: action, trigger: trigger, ctrl: ctrl),
    );
    settings.value = updated;
    await _repository.save(updated);
  }

  Future<void> resetShortcutDefaults() async {
    var updated = settings.value;
    for (final entry in AppSettings.defaultShortcutBindings.entries) {
      updated = updated.updateShortcutBinding(entry.key, entry.value);
    }
    settings.value = updated;
    await _repository.save(updated);
  }

  void _assertNoConflict({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    for (final entry in settings.value.shortcutBindings.entries) {
      if (entry.key == action) {
        continue;
      }
      final binding = entry.value;
      if (binding.trigger == trigger && binding.ctrl == ctrl) {
        throw StateError('快捷键冲突：${entry.key.name} 已使用该组合');
      }
    }
  }

  void _assertNoDuplicateChat(int chatId, {String? exceptKey}) {
    for (final item in settings.value.categories) {
      if (item.key == exceptKey) {
        continue;
      }
      if (item.targetChatId == chatId) {
        throw StateError('该群组或频道已经添加过了');
      }
    }
  }

  String _buildCategoryKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'cat_$now';
  }
}
