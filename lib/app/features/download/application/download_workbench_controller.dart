import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';

class DownloadWorkbenchController extends GetxController {
  DownloadWorkbenchController({
    required SessionQueryGateway sessions,
    required PipelineSettingsReader settings,
    required DownloadSyncPort sync,
  }) : _sessions = sessions,
       _settings = settings,
       _sync = sync;

  final SessionQueryGateway _sessions;
  final PipelineSettingsReader _settings;
  final DownloadSyncPort _sync;

  final chats = <SelectableChat>[].obs;
  final chatsLoading = false.obs;
  final selectedSourceChatId = RxnInt();
  final targetDirectory = ''.obs;
  final lastSummary = '选择来源和目标目录后会自动开始同步。'.obs;
  final activeSettings = AppSettings.defaults().obs;
  final syncing = false.obs;
  final copiedFiles = 0.obs;
  final skippedFiles = 0.obs;
  final deletedFiles = 0.obs;
  final scannedMessages = 0.obs;
  final lastError = RxnString();

  Worker? _settingsWorker;
  bool _pendingResync = false;

  bool get canRun =>
      activeSettings.value.downloadWorkbenchEnabled &&
      selectedSourceChatId.value != null &&
      targetDirectory.value.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    activeSettings.value = _settings.currentSettings;
    _settingsWorker = ever<AppSettings>(_settings.settingsStream, (settings) {
      activeSettings.value = settings;
      _scheduleSyncIfReady();
    });
    unawaited(loadChats());
  }

  Future<void> loadChats() async {
    chatsLoading.value = true;
    try {
      chats.assignAll(await _sessions.listSelectableChats());
    } finally {
      chatsLoading.value = false;
    }
  }

  void selectSourceChat(int? value) {
    selectedSourceChatId.value = value;
    _scheduleSyncIfReady();
  }

  void updateTargetDirectory(String value) {
    targetDirectory.value = value;
    _scheduleSyncIfReady();
  }

  void _scheduleSyncIfReady() {
    if (!canRun) {
      return;
    }
    if (syncing.value) {
      _pendingResync = true;
      return;
    }
    unawaited(_runSyncLoop());
  }

  Future<void> clearSessionStateForLogout() async {
    _pendingResync = false;
    syncing.value = false;
    selectedSourceChatId.value = null;
    targetDirectory.value = '';
    lastSummary.value = '选择来源和目标目录后会自动开始同步。';
    lastError.value = null;
    copiedFiles.value = 0;
    skippedFiles.value = 0;
    deletedFiles.value = 0;
    scannedMessages.value = 0;
    if (_sync is DownloadSyncSessionPort) {
      await (_sync as DownloadSyncSessionPort).clearSessionState();
    }
  }

  Future<void> _runSyncLoop() async {
    if (!canRun) {
      return;
    }
    syncing.value = true;
    do {
      _pendingResync = false;
      final sourceChatId = selectedSourceChatId.value;
      final targetDir = targetDirectory.value.trim();
      if (sourceChatId == null || targetDir.isEmpty) {
        syncing.value = false;
        return;
      }
      lastError.value = null;
      try {
        final result = await _sync.sync(
          sourceChatId: sourceChatId,
          sourceChatTitle: _sourceTitleOf(sourceChatId),
          targetDirectory: targetDir,
          settings: activeSettings.value.download,
        );
        scannedMessages.value = result.scannedMessages;
        copiedFiles.value = result.copiedFiles;
        skippedFiles.value = result.skippedFiles;
        deletedFiles.value = result.deletedFiles;
        lastSummary.value =
            '已扫描 ${result.scannedMessages} 条，新增 ${result.copiedFiles} 个，'
            '跳过 ${result.skippedFiles} 个，清理 ${result.deletedFiles} 个。';
      } catch (error) {
        lastError.value = '$error';
        lastSummary.value = '同步失败，请检查目录权限和 TDLib 本地文件状态。';
      }
    } while (_pendingResync && canRun);
    syncing.value = false;
  }

  String _sourceTitleOf(int sourceChatId) {
    for (final chat in chats) {
      if (chat.id == sourceChatId) {
        return chat.title;
      }
    }
    return 'chat_$sourceChatId';
  }

  @override
  void onClose() {
    _settingsWorker?.dispose();
    super.onClose();
  }
}
