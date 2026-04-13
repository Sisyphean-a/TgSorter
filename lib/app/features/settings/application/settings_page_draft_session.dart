import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/category_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/connection_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/settings_input_validator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/application/shortcut_settings_service.dart';
import 'package:tgsorter/app/features/settings/application/tag_settings_service.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class SettingsPageDraftSession {
  SettingsPageDraftSession({
    CategorySettingsService? categories,
    ConnectionSettingsService? connection,
    ShortcutSettingsService? shortcuts,
    SettingsInputValidator? validator,
    TagSettingsService? tags,
  }) : _categories = categories ?? CategorySettingsService(),
       _connection = connection ?? ConnectionSettingsService(),
       _shortcuts = shortcuts ?? ShortcutSettingsService(),
       _validator = validator ?? SettingsInputValidator(),
       _tags = tags ?? TagSettingsService();

  final CategorySettingsService _categories;
  final ConnectionSettingsService _connection;
  final ShortcutSettingsService _shortcuts;
  final SettingsInputValidator _validator;
  final TagSettingsService _tags;

  final currentRoute = Rxn<SettingsRoute>();
  final savedSettings = AppSettings.defaults().obs;
  final draftSettings = AppSettings.defaults().obs;
  final isDirty = false.obs;
  final hasValidationErrors = false.obs;

  bool get hasPendingChanges => isDirty.value || hasValidationErrors.value;

  void open({
    required SettingsRoute route,
    required AppSettings savedSettings,
  }) {
    currentRoute.value = route;
    this.savedSettings.value = savedSettings;
    draftSettings.value = savedSettings;
    isDirty.value = false;
    hasValidationErrors.value = false;
  }

  void markSaved(AppSettings savedSettings) {
    final route = currentRoute.value;
    if (route == null) {
      return;
    }
    open(route: route, savedSettings: savedSettings);
  }

  void discard() {
    draftSettings.value = savedSettings.value;
    isDirty.value = false;
    hasValidationErrors.value = false;
  }

  void clear() {
    currentRoute.value = null;
    savedSettings.value = AppSettings.defaults();
    draftSettings.value = AppSettings.defaults();
    isDirty.value = false;
    hasValidationErrors.value = false;
  }

  void updateSourceChat(int? sourceChatId) {
    _update(draftSettings.value.updateSourceChatId(sourceChatId));
  }

  void updateFetchDirection(MessageFetchDirection direction) {
    _update(draftSettings.value.updateFetchDirection(direction));
  }

  void updateForwardAsCopy(bool value) {
    _update(draftSettings.value.updateForwardAsCopy(value));
  }

  void updateBatchOptions({required int batchSize, required int throttleMs}) {
    _update(
      draftSettings.value.updateBatchOptions(
        batchSize: _validator.requireBatchSize(batchSize),
        throttleMs: _validator.requireThrottleMs(throttleMs),
      ),
    );
  }

  void updatePreviewPrefetchCount(int value) {
    _update(
      draftSettings.value.updatePreviewPrefetchCount(value < 0 ? 0 : value),
    );
  }

  void updateProxy({
    required String server,
    required String port,
    required String username,
    required String password,
  }) {
    _update(
      _connection.updateProxy(
        current: draftSettings.value,
        server: server,
        port: port,
        username: username,
        password: password,
      ),
    );
  }

  void updateThemeMode(AppThemeMode mode) {
    _update(draftSettings.value.copyWith(themeMode: mode));
  }

  void addCategory(SelectableChat chat) {
    _update(_categories.addCategory(current: draftSettings.value, chat: chat));
  }

  void updateCategory({required String key, required SelectableChat chat}) {
    _update(
      _categories.updateCategory(
        current: draftSettings.value,
        key: key,
        chat: chat,
      ),
    );
  }

  void removeCategory(String key) {
    _update(_categories.removeCategory(current: draftSettings.value, key: key));
  }

  void updateTagSourceChat(int? chatId) {
    _update(
      _tags.updateTagSourceChat(current: draftSettings.value, chatId: chatId),
    );
  }

  void addDefaultTag(String rawName) {
    _update(
      _tags.addDefaultTag(current: draftSettings.value, rawName: rawName),
    );
  }

  void removeDefaultTag(String rawName) {
    _update(
      _tags.removeDefaultTag(current: draftSettings.value, rawName: rawName),
    );
  }

  void updateShortcut({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) {
    _update(
      _shortcuts.updateShortcut(
        current: draftSettings.value,
        action: action,
        trigger: trigger,
        ctrl: ctrl,
      ),
    );
  }

  void resetShortcutDefaults() {
    _update(_shortcuts.resetDefaults(draftSettings.value));
  }

  void setHasValidationErrors(bool value) {
    hasValidationErrors.value = value;
  }

  void _update(AppSettings next) {
    draftSettings.value = next;
    isDirty.value = next != savedSettings.value;
  }
}
