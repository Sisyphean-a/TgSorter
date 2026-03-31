import 'package:get/get.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

class SettingsController extends GetxController {
  SettingsController(this._repository);

  final SettingsRepository _repository;
  final Rx<AppSettings> settings = AppSettings.defaults().obs;

  @override
  void onInit() {
    super.onInit();
    settings.value = _repository.load();
  }

  CategoryConfig getCategory(String key) {
    return settings.value.categories.firstWhere((item) => item.key == key);
  }

  Future<void> saveCategory({
    required String key,
    required String name,
    required String chatIdRaw,
  }) async {
    final chatId = int.tryParse(chatIdRaw.trim());
    final updated = settings.value.updateCategory(
      CategoryConfig(
        key: key,
        name: name.trim().isEmpty ? '未命名分类' : name.trim(),
        targetChatId: chatId,
      ),
    );
    settings.value = updated;
    await _repository.save(updated);
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
}
