import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_provider.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class SettingsController extends GetxController
    implements PipelineSettingsProvider {
  SettingsController(
    SettingsRepository repository,
    TelegramGateway telegram, {
    SettingsCoordinator? coordinator,
  }) : _coordinator =
           coordinator ?? SettingsCoordinator(repository, telegram, auth: telegram);

  final SettingsCoordinator _coordinator;

  Rx<AppSettings> get settings => _coordinator.savedSettings;
  Rx<AppSettings> get draftSettings => _coordinator.draftSettings;
  RxBool get isDirty => _coordinator.isDirty;
  RxList<SelectableChat> get chats => _coordinator.chats;
  RxBool get chatsLoading => _coordinator.chatsLoading;
  RxnString get chatsError => _coordinator.chatsError;

  @override
  Rx<AppSettings> get settingsStream => settings;

  @override
  AppSettings get currentSettings => settings.value;

  Rx<AppSettings> get savedSettings => settings;

  @override
  void onInit() {
    super.onInit();
    _coordinator.onInit();
  }

  @override
  CategoryConfig getCategory(String key) => _coordinator.getCategory(key);

  void updateSourceChatDraft(int? sourceChatId) =>
      _coordinator.updateSourceChatDraft(sourceChatId);

  void updateFetchDirectionDraft(MessageFetchDirection direction) =>
      _coordinator.updateFetchDirectionDraft(direction);

  void updateForwardAsCopyDraft(bool value) =>
      _coordinator.updateForwardAsCopyDraft(value);

  void updateBatchOptionsDraft({
    required int batchSize,
    required int throttleMs,
  }) => _coordinator.updateBatchOptionsDraft(
    batchSize: batchSize,
    throttleMs: throttleMs,
  );

  void updatePreviewPrefetchCountDraft(int value) =>
      _coordinator.updatePreviewPrefetchCountDraft(value);

  void updateProxyDraft({
    required String server,
    required String port,
    required String username,
    required String password,
  }) => _coordinator.updateProxyDraft(
    server: server,
    port: port,
    username: username,
    password: password,
  );

  void addCategoryDraft(SelectableChat chat) => _coordinator.addCategoryDraft(chat);

  void updateCategoryDraft({
    required String key,
    required SelectableChat chat,
  }) => _coordinator.updateCategoryDraft(key: key, chat: chat);

  void removeCategoryDraft(String key) => _coordinator.removeCategoryDraft(key);

  void updateShortcutDraft({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) => _coordinator.updateShortcutDraft(
    action: action,
    trigger: trigger,
    ctrl: ctrl,
  );

  void resetShortcutDefaultsDraft() => _coordinator.resetShortcutDefaultsDraft();

  void discardDraft() => _coordinator.discardDraft();

  Future<void> saveDraft() => _coordinator.saveDraft();

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
    await _coordinator.loadChats();
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
    _coordinator.updateProxyDraft(
      server: server,
      port: port,
      username: username,
      password: password,
    );
    await _coordinator.saveDraft(restartOnProxyChange: restart);
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
}
