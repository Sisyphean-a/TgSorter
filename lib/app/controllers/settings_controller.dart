import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_settings_provider.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class SettingsController extends GetxController
    implements PipelineSettingsProvider {
  SettingsController(this._repository, this._telegram);

  final SettingsRepository _repository;
  final TelegramGateway _telegram;

  final Rx<AppSettings> settings = AppSettings.defaults().obs;
  final Rx<AppSettings> draftSettings = AppSettings.defaults().obs;
  final RxBool isDirty = false.obs;
  final chats = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final chatsError = RxnString();

  @override
  Rx<AppSettings> get settingsStream => settings;

  @override
  AppSettings get currentSettings => settings.value;

  Rx<AppSettings> get savedSettings => settings;

  @override
  void onInit() {
    super.onInit();
    final loaded = _repository.load();
    settings.value = loaded;
    draftSettings.value = loaded;
    _syncDirtyState();
  }

  @override
  CategoryConfig getCategory(String key) {
    final category = _findCategory(draftSettings.value.categories, key);
    if (category != null) {
      return category;
    }
    return settings.value.categories.firstWhere((item) => item.key == key);
  }

  void updateSourceChatDraft(int? sourceChatId) {
    _updateDraft(draftSettings.value.updateSourceChatId(sourceChatId));
  }

  void updateFetchDirectionDraft(MessageFetchDirection direction) {
    _updateDraft(draftSettings.value.updateFetchDirection(direction));
  }

  void updateForwardAsCopyDraft(bool value) {
    _updateDraft(draftSettings.value.updateForwardAsCopy(value));
  }

  void updateBatchOptionsDraft({
    required int batchSize,
    required int throttleMs,
  }) {
    final safeBatchSize = batchSize < 1 ? 1 : batchSize;
    final safeThrottleMs = throttleMs < 0 ? 0 : throttleMs;
    _updateDraft(
      draftSettings.value.updateBatchOptions(
        batchSize: safeBatchSize,
        throttleMs: safeThrottleMs,
      ),
    );
  }

  void updatePreviewPrefetchCountDraft(int value) {
    final safeValue = value < 0 ? 0 : value;
    _updateDraft(draftSettings.value.updatePreviewPrefetchCount(safeValue));
  }

  void updateProxyDraft({
    required String server,
    required String port,
    required String username,
    required String password,
  }) {
    _updateDraft(
      draftSettings.value.updateProxySettings(
        ProxySettings(
          server: server,
          port: int.tryParse(port.trim()),
          username: username,
          password: password,
        ),
      ),
    );
  }

  void addCategoryDraft(SelectableChat chat) {
    _assertNoDuplicateChat(chat.id);
    _updateDraft(
      draftSettings.value.addCategory(
        CategoryConfig(
          key: _buildCategoryKey(),
          targetChatId: chat.id,
          targetChatTitle: chat.title,
        ),
      ),
    );
  }

  void updateCategoryDraft({
    required String key,
    required SelectableChat chat,
  }) {
    _assertNoDuplicateChat(chat.id, exceptKey: key);
    _updateDraft(
      draftSettings.value.updateCategory(
        CategoryConfig(
          key: key,
          targetChatId: chat.id,
          targetChatTitle: chat.title,
        ),
      ),
    );
  }

  void removeCategoryDraft(String key) {
    _updateDraft(draftSettings.value.removeCategory(key));
  }

  void updateShortcutDraft({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    _assertNoConflict(action: action, trigger: trigger, ctrl: ctrl);
    _updateDraft(
      draftSettings.value.updateShortcutBinding(
        action,
        ShortcutBinding(action: action, trigger: trigger, ctrl: ctrl),
      ),
    );
  }

  void resetShortcutDefaultsDraft() {
    _updateDraft(
      draftSettings.value.copyWith(
        shortcutBindings: AppSettings.defaultShortcutBindings,
      ),
    );
  }

  void discardDraft() {
    draftSettings.value = settings.value;
    _syncDirtyState();
  }

  Future<void> saveDraft() async {
    final previous = settings.value;
    final next = draftSettings.value;
    final proxyChanged = previous.proxy != next.proxy;
    await _repository.save(next);
    settings.value = next;
    _syncDirtyState();
    if (!proxyChanged) {
      return;
    }
    await _telegram.restart();
  }

  Future<void> addCategory(SelectableChat chat) async {
    addCategoryDraft(chat);
    await saveDraft();
  }

  Future<void> updateCategoryTarget({
    required String key,
    required SelectableChat chat,
  }) async {
    updateCategoryDraft(key: key, chat: chat);
    await saveDraft();
  }

  Future<void> removeCategory(String key) async {
    removeCategoryDraft(key);
    await saveDraft();
  }

  Future<void> saveSourceChat(int? sourceChatId) async {
    updateSourceChatDraft(sourceChatId);
    await saveDraft();
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
    updateFetchDirectionDraft(direction);
    await saveDraft();
  }

  Future<void> saveForwardAsCopy(bool value) async {
    updateForwardAsCopyDraft(value);
    await saveDraft();
  }

  Future<void> saveBatchOptions({
    required int batchSize,
    required int throttleMs,
  }) async {
    updateBatchOptionsDraft(batchSize: batchSize, throttleMs: throttleMs);
    await saveDraft();
  }

  Future<void> saveProxySettings({
    required String server,
    required String port,
    required String username,
    required String password,
    bool restart = false,
  }) async {
    updateProxyDraft(
      server: server,
      port: port,
      username: username,
      password: password,
    );
    final previous = settings.value;
    final next = draftSettings.value;
    await _repository.save(next);
    settings.value = next;
    _syncDirtyState();
    if (!restart || previous.proxy == next.proxy) {
      return;
    }
    await _telegram.restart();
  }

  Future<void> saveShortcutBinding({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) async {
    updateShortcutDraft(action: action, trigger: trigger, ctrl: ctrl);
    await saveDraft();
  }

  Future<void> resetShortcutDefaults() async {
    resetShortcutDefaultsDraft();
    await saveDraft();
  }

  void _updateDraft(AppSettings next) {
    draftSettings.value = next;
    _syncDirtyState();
  }

  void _syncDirtyState() {
    isDirty.value = draftSettings.value != settings.value;
  }

  void _assertNoConflict({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    for (final entry in draftSettings.value.shortcutBindings.entries) {
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
    for (final item in draftSettings.value.categories) {
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

  CategoryConfig? _findCategory(List<CategoryConfig> categories, String key) {
    for (final item in categories) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }
}
