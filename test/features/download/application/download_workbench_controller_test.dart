import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/domain/download_settings.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';

void main() {
  test('does not auto sync until workbench is enabled and fully configured', () async {
    final settings = _FakeSettingsReader(AppSettings.defaults());
    final sync = _FakeDownloadSyncPort();
    final controller = DownloadWorkbenchController(
      sessions: _FakeSessionGateway(),
      settings: settings,
      sync: sync,
    );

    controller.onInit();
    controller.selectSourceChat(777);
    controller.updateTargetDirectory('/tmp/downloads');
    await Future<void>.delayed(Duration.zero);

    expect(sync.calls, isEmpty);
  });

  test('auto syncs after source and directory become valid', () async {
    final settings = _FakeSettingsReader(
      AppSettings.defaults().updateDownloadSettings(
        workbenchEnabled: true,
        skipExistingFiles: true,
        syncDeletedFiles: false,
        conflictStrategy: DownloadConflictStrategy.rename,
        mediaFilter: DownloadMediaFilter.all,
        directoryMode: DownloadDirectoryMode.flat,
      ),
    );
    final sync = _FakeDownloadSyncPort();
    final controller = DownloadWorkbenchController(
      sessions: _FakeSessionGateway(),
      settings: settings,
      sync: sync,
    );

    controller.onInit();
    controller.selectSourceChat(777);
    controller.updateTargetDirectory('/tmp/downloads');
    await Future<void>.delayed(Duration.zero);

    expect(sync.calls, hasLength(1));
    expect(sync.calls.single.sourceChatId, 777);
    expect(sync.calls.single.targetDirectory, '/tmp/downloads');
  });

  test('clearSessionStateForLogout resets selection and clears sync session state', () async {
    final settings = _FakeSettingsReader(
      AppSettings.defaults().updateDownloadSettings(
        workbenchEnabled: true,
        skipExistingFiles: true,
        syncDeletedFiles: false,
        conflictStrategy: DownloadConflictStrategy.rename,
        mediaFilter: DownloadMediaFilter.all,
        directoryMode: DownloadDirectoryMode.flat,
      ),
    );
    final sync = _FakeDownloadSyncPort();
    final controller = DownloadWorkbenchController(
      sessions: _FakeSessionGateway(),
      settings: settings,
      sync: sync,
    );

    controller.onInit();
    controller.selectSourceChat(777);
    controller.updateTargetDirectory('/tmp/downloads');
    await Future<void>.delayed(Duration.zero);

    expect(controller.selectedSourceChatId.value, 777);
    expect(controller.targetDirectory.value, '/tmp/downloads');

    await controller.clearSessionStateForLogout();

    expect(controller.selectedSourceChatId.value, isNull);
    expect(controller.targetDirectory.value, isEmpty);
    expect(controller.chats, isEmpty);
    expect(sync.clearCalls, 1);
  });

  test(
    'clearSessionStateForLogout ignores stale sync result from previous session',
    () async {
      final settings = _FakeSettingsReader(
        AppSettings.defaults().updateDownloadSettings(
          workbenchEnabled: true,
          skipExistingFiles: true,
          syncDeletedFiles: false,
          conflictStrategy: DownloadConflictStrategy.rename,
          mediaFilter: DownloadMediaFilter.all,
          directoryMode: DownloadDirectoryMode.flat,
        ),
      );
      final sync = _FakeDownloadSyncPort();
      final pendingResult = Completer<DownloadSyncResult>();
      sync.nextResult = pendingResult.future;
      final controller = DownloadWorkbenchController(
        sessions: _FakeSessionGateway(),
        settings: settings,
        sync: sync,
      );

      controller.onInit();
      controller.selectSourceChat(777);
      controller.updateTargetDirectory('/tmp/downloads');
      await Future<void>.delayed(Duration.zero);

      expect(sync.calls, hasLength(1));
      expect(controller.syncing.value, isTrue);

      await controller.clearSessionStateForLogout();

      pendingResult.complete(
        const DownloadSyncResult(
          scannedMessages: 9,
          copiedFiles: 6,
          skippedFiles: 2,
          deletedFiles: 1,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.syncing.value, isFalse);
      expect(controller.selectedSourceChatId.value, isNull);
      expect(controller.targetDirectory.value, isEmpty);
      expect(controller.scannedMessages.value, 0);
      expect(controller.copiedFiles.value, 0);
      expect(controller.skippedFiles.value, 0);
      expect(controller.deletedFiles.value, 0);
      expect(
        controller.lastSummary.value,
        '选择来源和目标目录后会自动开始同步。',
      );
      expect(controller.lastError.value, isNull);
      expect(sync.clearCalls, 1);
    },
  );

  test('clearSessionStateForLogout ignores stale chat load result', () async {
    final sessions = _FakeSessionGateway();
    final pendingChats = Completer<List<SelectableChat>>();
    sessions.nextChats = pendingChats.future;
    final controller = DownloadWorkbenchController(
      sessions: sessions,
      settings: _FakeSettingsReader(AppSettings.defaults()),
      sync: _FakeDownloadSyncPort(),
    );

    controller.onInit();
    final loadFuture = controller.loadChats();
    await Future<void>.delayed(Duration.zero);

    expect(controller.chatsLoading.value, isTrue);

    await controller.clearSessionStateForLogout();
    pendingChats.complete(const [SelectableChat(id: 99, title: '旧会话来源')]);
    await loadFuture;

    expect(controller.chats, isEmpty);
    expect(controller.chatsLoading.value, isFalse);
    expect(controller.selectedSourceChatId.value, isNull);
  });

  test('loadChats keeps latest result when multiple loads overlap', () async {
    final sessions = _FakeSessionGateway();
    final firstChats = Completer<List<SelectableChat>>();
    final secondChats = Completer<List<SelectableChat>>();
    sessions.queuedChats.addAll([firstChats.future, secondChats.future]);
    final controller = DownloadWorkbenchController(
      sessions: sessions,
      settings: _FakeSettingsReader(AppSettings.defaults()),
      sync: _FakeDownloadSyncPort(),
    );

    controller.onInit();
    final firstLoad = controller.loadChats();
    final secondLoad = controller.loadChats();
    await Future<void>.delayed(Duration.zero);

    secondChats.complete(const [SelectableChat(id: 2, title: '新列表')]);
    await secondLoad;
    expect(controller.chats.single.id, 2);

    firstChats.complete(const [SelectableChat(id: 1, title: '旧列表')]);
    await firstLoad;

    expect(controller.chats, hasLength(1));
    expect(controller.chats.single.id, 2);
    expect(controller.chatsLoading.value, isFalse);
  });
}

class _FakeSettingsReader implements PipelineSettingsReader {
  _FakeSettingsReader(AppSettings initial) : settingsStream = initial.obs;

  @override
  final Rx<AppSettings> settingsStream;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    throw UnimplementedError();
  }
}

class _FakeSessionGateway implements SessionQueryGateway {
  Future<List<SelectableChat>>? nextChats;
  final queuedChats = <Future<List<SelectableChat>>>[];

  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    if (queuedChats.isNotEmpty) {
      return queuedChats.removeAt(0);
    }
    final result = nextChats;
    nextChats = null;
    if (result != null) {
      return result;
    }
    return const [SelectableChat(id: 777, title: '下载来源')];
  }
}

class _FakeDownloadSyncPort
    implements DownloadSyncPort, DownloadSyncSessionPort {
  final calls = <_SyncCall>[];
  int clearCalls = 0;
  Future<DownloadSyncResult>? nextResult;

  @override
  Future<DownloadSyncResult> sync({
    required int sourceChatId,
    required String sourceChatTitle,
    required String targetDirectory,
    required DownloadSettings settings,
  }) async {
    calls.add(
      _SyncCall(
        sourceChatId: sourceChatId,
        sourceChatTitle: sourceChatTitle,
        targetDirectory: targetDirectory,
      ),
    );
    final result = nextResult;
    nextResult = null;
    if (result != null) {
      return result;
    }
    return const DownloadSyncResult(
      scannedMessages: 3,
      copiedFiles: 2,
      skippedFiles: 1,
      deletedFiles: 0,
    );
  }

  @override
  Future<void> clearSessionState() async {
    clearCalls++;
  }
}

class _SyncCall {
  const _SyncCall({
    required this.sourceChatId,
    required this.sourceChatTitle,
    required this.targetDirectory,
  });

  final int sourceChatId;
  final String sourceChatTitle;
  final String targetDirectory;
}
