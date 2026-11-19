import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/skipped_message_summary.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_port.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_registry.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

class SettingsCoordinator extends GetxController
    implements PipelineSettingsReader {
  SettingsCoordinator(
    SettingsRepository repository,
    SessionQueryGateway sessions, {
    AuthGateway? auth,
    SettingsPersistenceService? persistence,
    SettingsChatLoader? chatLoader,
    SkippedMessageRepository? skippedMessageRepository,
    SkippedMessageRestoreRegistry? skippedRestoreRegistry,
    List<SkippedMessageRestorePort>? skippedRestoreTargets,
  }) : _auth = auth,
       _persistence = persistence ?? SettingsPersistenceService(repository),
       _chatLoader =
           chatLoader ?? SettingsChatLoader(sessionQueryGateway: sessions),
       _skippedMessageRepository =
           skippedMessageRepository ?? NoopSkippedMessageRepository.instance,
       _skippedRestoreRegistry = skippedRestoreRegistry,
       _skippedRestoreTargets = skippedRestoreTargets;

  final AuthGateway? _auth;
  final SettingsPersistenceService _persistence;
  final SettingsChatLoader _chatLoader;
  final SkippedMessageRepository _skippedMessageRepository;
  final SkippedMessageRestoreRegistry? _skippedRestoreRegistry;
  final List<SkippedMessageRestorePort>? _skippedRestoreTargets;
  final _savedState = AppSettings.defaults().obs;
  final _draftState = AppSettings.defaults().obs;
  Future<void>? _pendingSaveDraft;
  Future<void>? _pendingChatLoad;
  final _saveState = false.obs;
  final _chatsState = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final chatsError = RxnString();
  final _skippedMessageSummaryState = const SkippedMessageSummary.empty().obs;

  Rx<AppSettings> get savedSettings => _savedState;
  RxBool get isSaving => _saveState;
  RxList<SelectableChat> get chats => _chatsState;
  Rx<SkippedMessageSummary> get skippedMessageSummary =>
      _skippedMessageSummaryState;

  @override
  Rx<AppSettings> get settingsStream => savedSettings;

  @override
  AppSettings get currentSettings => savedSettings.value;

  @override
  void onInit() {
    super.onInit();
    _replaceDraftState(_persistence.load());
    refreshSkippedMessageSummary();
  }

  @override
  CategoryConfig getCategory(String key) {
    return savedSettings.value.categories.firstWhere((item) => item.key == key);
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
    _skippedMessageSummaryState.value = SkippedMessageSummary.fromRecords(
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

  Future<void> savePageDraft(AppSettings next) async {
    final pending = _pendingSaveDraft;
    if (pending != null) {
      return pending;
    }
    final previousDraft = _draftState.value;
    _updateDraft(next);
    final completer = Completer<void>();
    _pendingSaveDraft = completer.future;
    _saveState.value = true;
    unawaited(() async {
      try {
        await _persistence.save(next);
        _commitDraft();
        completer.complete();
      } catch (error, stackTrace) {
        _updateDraft(previousDraft);
        completer.completeError(error, stackTrace);
      } finally {
        _saveState.value = false;
        _pendingSaveDraft = null;
      }
    }());
    return completer.future;
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

  void _replaceDraftState(AppSettings next) {
    _savedState.value = next;
    _draftState.value = next;
  }

  void _updateDraft(AppSettings next) {
    _draftState.value = next;
  }

  void _commitDraft() {
    _savedState.value = _draftState.value;
  }
}
