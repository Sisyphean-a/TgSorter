import 'package:get/get.dart';
import 'package:tgsorter/app/features/auth/application/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/category_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/chat_selection_service.dart';
import 'package:tgsorter/app/features/settings/application/connection_settings_service.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_session.dart';
import 'package:tgsorter/app/features/settings/application/shortcut_settings_service.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

import 'session_query_gateway.dart';

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(
    this._repository,
    this._sessions, {
    AuthGateway? auth,
    SettingsDraftSession? draftSession,
    CategorySettingsService? categories,
    ShortcutSettingsService? shortcuts,
    ConnectionSettingsService? connection,
    ChatSelectionService? chats,
  }) : _auth = auth,
       _draftSession = draftSession ?? SettingsDraftSession(AppSettings.defaults()),
       _categories = categories ?? CategorySettingsService(),
       _shortcuts = shortcuts ?? ShortcutSettingsService(),
       _connection = connection ?? ConnectionSettingsService(),
       _chats =
           chats ?? ChatSelectionService(sessionQueryGateway: _sessions);

  final SettingsRepository _repository;
  final SessionQueryGateway _sessions;
  final AuthGateway? _auth;
  final SettingsDraftSession _draftSession;
  final CategorySettingsService _categories;
  final ShortcutSettingsService _shortcuts;
  final ConnectionSettingsService _connection;
  final ChatSelectionService _chats;
  final chatsState = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final chatsError = RxnString();

  SettingsRepository get repository => _repository;
  SessionQueryGateway get sessions => _sessions;
  Rx<AppSettings> get savedSettings => _draftSession.saved;
  Rx<AppSettings> get draftSettings => _draftSession.draft;
  RxBool get isDirty => _draftSession.isDirty;
  RxList<SelectableChat> get chats => chatsState;

  @override
  Rx<AppSettings> get settingsStream => savedSettings;

  @override
  AppSettings get currentSettings => savedSettings.value;

  @override
  void onInit() {
    super.onInit();
    _draftSession.replace(_repository.load());
  }

  @override
  CategoryConfig getCategory(String key) {
    CategoryConfig? category;
    for (final item in draftSettings.value.categories) {
      if (item.key == key) {
        category = item;
        break;
      }
    }
    if (category != null) {
      return category;
    }
    return savedSettings.value.categories.firstWhere((item) => item.key == key);
  }

  void updateSourceChatDraft(int? sourceChatId) {
    _draftSession.update(draftSettings.value.updateSourceChatId(sourceChatId));
  }

  void updateFetchDirectionDraft(MessageFetchDirection direction) {
    _draftSession.update(draftSettings.value.updateFetchDirection(direction));
  }

  void updateForwardAsCopyDraft(bool value) {
    _draftSession.update(draftSettings.value.updateForwardAsCopy(value));
  }

  void updateBatchOptionsDraft({
    required int batchSize,
    required int throttleMs,
  }) {
    final safeBatchSize = batchSize < 1 ? 1 : batchSize;
    final safeThrottleMs = throttleMs < 0 ? 0 : throttleMs;
    _draftSession.update(
      draftSettings.value.updateBatchOptions(
        batchSize: safeBatchSize,
        throttleMs: safeThrottleMs,
      ),
    );
  }

  void updatePreviewPrefetchCountDraft(int value) {
    _draftSession.update(
      draftSettings.value.updatePreviewPrefetchCount(value < 0 ? 0 : value),
    );
  }

  void updateProxyDraft({
    required String server,
    required String port,
    required String username,
    required String password,
  }) {
    _draftSession.update(
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
    _draftSession.update(
      _categories.addCategory(current: draftSettings.value, chat: chat),
    );
  }

  void updateCategoryDraft({
    required String key,
    required SelectableChat chat,
  }) {
    _draftSession.update(
      _categories.updateCategory(
        current: draftSettings.value,
        key: key,
        chat: chat,
      ),
    );
  }

  void removeCategoryDraft(String key) {
    _draftSession.update(
      _categories.removeCategory(current: draftSettings.value, key: key),
    );
  }

  void updateShortcutDraft({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    _draftSession.update(
      _shortcuts.updateShortcut(
        current: draftSettings.value,
        action: action,
        trigger: trigger,
        ctrl: ctrl,
      ),
    );
  }

  void resetShortcutDefaultsDraft() {
    _draftSession.update(_shortcuts.resetDefaults(draftSettings.value));
  }

  void discardDraft() => _draftSession.discard();

  Future<void> saveDraft({bool restartOnProxyChange = true}) async {
    final previous = savedSettings.value;
    final next = draftSettings.value;
    final proxyChanged = previous.proxy != next.proxy;
    await _repository.save(next);
    _draftSession.commit();
    if (proxyChanged && restartOnProxyChange && _auth != null) {
      await _auth.restart();
    }
  }

  Future<void> loadChats() async {
    chatsLoading.value = true;
    chatsError.value = null;
    try {
      chats.assignAll(await _chats.loadChats());
    } catch (error) {
      chatsError.value = error.toString();
      rethrow;
    } finally {
      chatsLoading.value = false;
    }
  }
}
