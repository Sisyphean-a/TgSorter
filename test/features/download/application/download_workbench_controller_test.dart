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
    expect(sync.clearCalls, 1);
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
  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    return const [SelectableChat(id: 777, title: '下载来源')];
  }
}

class _FakeDownloadSyncPort
    implements DownloadSyncPort, DownloadSyncSessionPort {
  final calls = <_SyncCall>[];
  int clearCalls = 0;

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
