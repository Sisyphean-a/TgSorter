import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_settings_port.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/category_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/connection_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/skipped_message_summary.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_input_validator.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/features/settings/application/settings_restart_policy.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/features/settings/application/shortcut_settings_service.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_port.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_registry.dart';
import 'package:tgsorter/app/features/settings/application/tag_settings_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

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
    SettingsInputValidator? validator,
    TagSettingsService? tags,
    SettingsChatLoader? chatLoader,
    SkippedMessageRepository? skippedMessageRepository,
    SkippedMessageRestoreRegistry? skippedRestoreRegistry,
    List<SkippedMessageRestorePort>? skippedRestoreTargets,
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
       _validator = validator ?? SettingsInputValidator(),
       _tags = tags ?? TagSettingsService(),
       _chatLoader =
           chatLoader ?? SettingsChatLoader(sessionQueryGateway: sessions),
       _skippedMessageRepository =
           skippedMessageRepository ?? NoopSkippedMessageRepository.instance,
       _skippedRestoreRegistry = skippedRestoreRegistry,
       _skippedRestoreTargets = skippedRestoreTargets;

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
  final AuthGateway? _auth;
  final SettingsDraftCoordinator _draftCoordinator;
  final SettingsPersistenceService _persistence;
  final SettingsRestartPolicy _restartPolicy;
  final CategorySettingsService _categories;
  final ShortcutSettingsService _shortcuts;
  final ConnectionSettingsService _connection;
  final SettingsInputValidator _validator;
  final TagSettingsService _tags;
  final SettingsChatLoader _chatLoader;
  final SkippedMessageRepository _skippedMessageRepository;
  final SkippedMessageRestoreRegistry? _skippedRestoreRegistry;
  final List<SkippedMessageRestorePort>? _skippedRestoreTargets;
  Future<SettingsSaveResult>? _pendingSaveDraft;
  Future<void>? _pendingChatLoad;
  final saveState = false.obs;
  final chatsState = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final chatsError = RxnString();
  final skippedMessageSummaryState = const SkippedMessageSummary.empty().obs;

  SettingsRepository get repository => _repository;
  SessionQueryGateway get sessions => _sessions;
  Rx<AppSettings> get settings => savedSettings;
  Rx<AppSettings> get savedSettings => _draftCoordinator.saved;
  Rx<AppSettings> get draftSettings => _draftCoordinator.draft;
  RxBool get isDirty => _draftCoordinator.isDirty;
  RxBool get isSaving => saveState;
  RxList<SelectableChat> get chats => chatsState;
  Rx<SkippedMessageSummary> get skippedMessageSummary =>
      skippedMessageSummaryState;

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
    refreshSkippedMessageSummary();
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
    _draftCoordinator.update(
      draftSettings.value.updateBatchOptions(
        batchSize: _validator.requireBatchSize(batchSize),
        throttleMs: _validator.requireThrottleMs(throttleMs),
      ),
    );
  }

  void updatePreviewPrefetchCountDraft(int value) {
    _draftCoordinator.update(
      draftSettings.value.updatePreviewPrefetchCount(value < 0 ? 0 : value),
    );
  }

  void updateMediaLoadOptionsDraft({
    required int backgroundConcurrency,
    required int retryLimit,
    required int retryDelayMs,
  }) {
    _draftCoordinator.update(
      draftSettings.value.updateMediaLoadOptions(
        backgroundConcurrency: _validator
            .requireMediaBackgroundDownloadConcurrency(backgroundConcurrency),
        retryLimit: _validator.requireMediaRetryLimit(retryLimit),
        retryDelayMs: _validator.requireMediaRetryDelayMs(retryDelayMs),
      ),
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

  void updateThemeModeDraft(AppThemeMode mode) {
    _draftCoordinator.update(draftSettings.value.copyWith(themeMode: mode));
  }

  void updateDefaultWorkbenchDraft(AppDefaultWorkbench value) {
    _draftCoordinator.update(draftSettings.value.updateDefaultWorkbench(value));
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

  void updateTagSourceChatDraft(int? chatId) {
    _draftCoordinator.update(
      _tags.updateTagSourceChat(current: draftSettings.value, chatId: chatId),
    );
  }

  void addDefaultTagDraft(String rawName) {
    _draftCoordinator.update(
      _tags.addDefaultTag(current: draftSettings.value, rawName: rawName),
    );
  }

  void removeDefaultTagDraft(String rawName) {
    _draftCoordinator.update(
      _tags.removeDefaultTag(current: draftSettings.value, rawName: rawName),
    );
  }

  void discardDraft() => _draftCoordinator.discard();

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

  Future<void> logout() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('当前环境未提供退出登录能力');
    }
    await auth.logout();
  }

  Future<void> clearSessionStateForLogout() async {
    await _skippedMessageRepository.clearAll();
    refreshSkippedMessageSummary();
  }

  void refreshSkippedMessageSummary() {
    skippedMessageSummaryState.value = SkippedMessageSummary.fromRecords(
      _skippedMessageRepository.loadSkippedMessages(),
    );
  }

  Future<int> restoreSkippedMessages({
    SkippedMessageWorkflow? workflow,
    int? sourceChatId,
  }) async {
    final restored = await _skippedMessageRepository.restoreSkippedMessages(
      workflow: workflow,
      sourceChatId: sourceChatId,
    );
    refreshSkippedMessageSummary();
    if (restored <= 0) {
      return 0;
    }
    for (final target in _resolveSkippedRestoreTargets()) {
      if (workflow != null && target.workflow != workflow) {
        continue;
      }
      await target.reloadAfterSkippedRestore(sourceChatId: sourceChatId);
    }
    return restored;
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
    saveState.value = true;
    unawaited(() async {
      try {
        completer.complete(
          await _saveDraftInternal(restartOnProxyChange: restartOnProxyChange),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        saveState.value = false;
        if (identical(_pendingSaveDraft, completer.future)) {
          _pendingSaveDraft = null;
        }
      }
    }());
    return completer.future;
  }

  Future<SettingsSaveResult> savePageDraft(
    AppSettings next, {
    bool restartOnProxyChange = true,
  }) async {
    final pending = _pendingSaveDraft;
    if (pending != null) {
      return pending;
    }
    final previousDraft = draftSettings.value;
    _draftCoordinator.update(next);
    try {
      return await saveDraft(restartOnProxyChange: restartOnProxyChange);
    } catch (_) {
      _draftCoordinator.update(previousDraft);
      rethrow;
    }
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

  List<SkippedMessageRestorePort> _resolveSkippedRestoreTargets() {
    final explicitTargets = _skippedRestoreTargets;
    if (explicitTargets != null) {
      return explicitTargets;
    }
    return _skippedRestoreRegistry?.targets ??
        const <SkippedMessageRestorePort>[];
  }
}
