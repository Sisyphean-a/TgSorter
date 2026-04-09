import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_settings_port.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/category_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/connection_settings_service.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/features/settings/application/settings_restart_policy.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/features/settings/application/shortcut_settings_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader, AuthSettingsPort {
  SettingsCoordinator(
    SettingsRepository repository,
    SessionQueryGateway sessions, {
    AuthGateway? auth,
    SettingsDraftCoordinator? draftCoordinator,
    SettingsPersistenceService? persistence,
    SettingsRestartPolicy? restartPolicy,
    CategorySettingsService? categories,
    ShortcutSettingsService? shortcuts,
    ConnectionSettingsService? connection,
    SettingsChatLoader? chatLoader,
  }) : _repository = repository,
       _sessions = sessions,
       _auth = auth,
       _draftCoordinator =
           draftCoordinator ?? SettingsDraftCoordinator(AppSettings.defaults()),
       _persistence = persistence ?? SettingsPersistenceService(repository),
       _restartPolicy = restartPolicy ?? SettingsRestartPolicy(),
       _categories = categories ?? CategorySettingsService(),
       _shortcuts = shortcuts ?? ShortcutSettingsService(),
       _connection = connection ?? ConnectionSettingsService(),
       _chatLoader =
           chatLoader ?? SettingsChatLoader(sessionQueryGateway: sessions);

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
  final AuthGateway? _auth;
  final SettingsDraftCoordinator _draftCoordinator;
  final SettingsPersistenceService _persistence;
  final SettingsRestartPolicy _restartPolicy;
  final CategorySettingsService _categories;
  final ShortcutSettingsService _shortcuts;
  final ConnectionSettingsService _connection;
  final SettingsChatLoader _chatLoader;
  Future<SettingsSaveResult>? _pendingSaveDraft;
  Future<void>? _pendingChatLoad;
  final chatsState = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final chatsError = RxnString();

  SettingsRepository get repository => _repository;
  SessionQueryGateway get sessions => _sessions;
  Rx<AppSettings> get settings => savedSettings;
  Rx<AppSettings> get savedSettings => _draftCoordinator.saved;
  Rx<AppSettings> get draftSettings => _draftCoordinator.draft;
  RxBool get isDirty => _draftCoordinator.isDirty;
  RxList<SelectableChat> get chats => chatsState;

  @override
  Rx<AppSettings> get settingsStream => savedSettings;

  @override
  AppSettings get currentSettings => savedSettings.value;

  @override
  ProxySettings get currentProxySettings => savedSettings.value.proxy;

  @override
  void onInit() {
    super.onInit();
    _draftCoordinator.replace(_persistence.load());
  }

  @override
  CategoryConfig getCategory(String key) {
    return savedSettings.value.categories.firstWhere((item) => item.key == key);
  }

  void updateSourceChatDraft(int? sourceChatId) {
    _draftCoordinator.update(
      draftSettings.value.updateSourceChatId(sourceChatId),
    );
  }

  void updateFetchDirectionDraft(MessageFetchDirection direction) {
    _draftCoordinator.update(
      draftSettings.value.updateFetchDirection(direction),
    );
  }

  void updateForwardAsCopyDraft(bool value) {
    _draftCoordinator.update(draftSettings.value.updateForwardAsCopy(value));
  }

  void updateBatchOptionsDraft({
    required int batchSize,
    required int throttleMs,
  }) {
    final safeBatchSize = batchSize < 1 ? 1 : batchSize;
    final safeThrottleMs = throttleMs < 0 ? 0 : throttleMs;
    _draftCoordinator.update(
      draftSettings.value.updateBatchOptions(
        batchSize: safeBatchSize,
        throttleMs: safeThrottleMs,
      ),
    );
  }

  void updatePreviewPrefetchCountDraft(int value) {
    _draftCoordinator.update(
      draftSettings.value.updatePreviewPrefetchCount(value < 0 ? 0 : value),
    );
  }

  void updateProxyDraft({
    required String server,
    required String port,
    required String username,
    required String password,
  }) {
    _draftCoordinator.update(
      _connection.updateProxy(
        current: draftSettings.value,
        server: server,
        port: port,
        username: username,
        password: password,
      ),
    );
  }

  void addCategoryDraft(SelectableChat chat) {
    _draftCoordinator.update(
      _categories.addCategory(current: draftSettings.value, chat: chat),
    );
  }

  void updateCategoryDraft({
    required String key,
    required SelectableChat chat,
  }) {
    _draftCoordinator.update(
      _categories.updateCategory(
        current: draftSettings.value,
        key: key,
        chat: chat,
      ),
    );
  }

  void removeCategoryDraft(String key) {
    _draftCoordinator.update(
      _categories.removeCategory(current: draftSettings.value, key: key),
    );
  }

  void updateShortcutDraft({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    _draftCoordinator.update(
      _shortcuts.updateShortcut(
        current: draftSettings.value,
        action: action,
        trigger: trigger,
        ctrl: ctrl,
      ),
    );
  }

  void resetShortcutDefaultsDraft() {
    _draftCoordinator.update(_shortcuts.resetDefaults(draftSettings.value));
  }

  void discardDraft() => _draftCoordinator.discard();

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

  @override
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
    await saveDraft(restartOnProxyChange: restart);
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

  Future<SettingsSaveResult> saveDraft({
    bool restartOnProxyChange = true,
  }) async {
    final pending = _pendingSaveDraft;
    if (pending != null) {
      return pending;
    }
    final completer = Completer<SettingsSaveResult>();
    _pendingSaveDraft = completer.future;
    unawaited(() async {
      try {
        completer.complete(
          await _saveDraftInternal(restartOnProxyChange: restartOnProxyChange),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (identical(_pendingSaveDraft, completer.future)) {
          _pendingSaveDraft = null;
        }
      }
    }());
    return completer.future;
  }

  Future<SettingsSaveResult> _saveDraftInternal({
    required bool restartOnProxyChange,
  }) async {
    final previous = savedSettings.value;
    final next = draftSettings.value;
    await _persistence.save(next);
    _draftCoordinator.commit();
    final shouldRestart = _restartPolicy.shouldRestart(previous, next);
    if (!shouldRestart || !restartOnProxyChange || _auth == null) {
      return SettingsSaveResult.saved;
    }
    try {
      await _auth.restart();
      return SettingsSaveResult.savedAndRestarted;
    } catch (_) {
      return SettingsSaveResult.savedNeedsRestartAttention;
    }
  }

  Future<void> loadChats() async {
    final pending = _pendingChatLoad;
    if (pending != null) {
      return pending;
    }
    final completer = Completer<void>();
    _pendingChatLoad = completer.future;
    unawaited(() async {
      try {
        await _loadChatsInternal();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (identical(_pendingChatLoad, completer.future)) {
          _pendingChatLoad = null;
        }
      }
    }());
    return completer.future;
  }

  Future<void> _loadChatsInternal() async {
    chatsLoading.value = true;
    chatsError.value = null;
    try {
      chats.assignAll(await _chatLoader.loadChats());
    } catch (error) {
      chatsError.value = error.toString();
      rethrow;
    } finally {
      chatsLoading.value = false;
    }
  }
}
