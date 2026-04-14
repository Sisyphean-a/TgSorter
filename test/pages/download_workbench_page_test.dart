import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/download/presentation/download_workbench_page.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/domain/download_settings.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets(
    'download workbench loads chats on mount and reloads them on remount',
    (tester) async {
    Get.testMode = true;
    Get.reset();
    final sessions = _MutableSessionGateway(
      const [SelectableChat(id: 1, title: '会话一')],
    );
    final controller = DownloadWorkbenchController(
      sessions: sessions,
      settings: _FakeSettingsReader(
        AppSettings.defaults().updateDownloadSettings(
          workbenchEnabled: true,
          skipExistingFiles: true,
          syncDeletedFiles: false,
          conflictStrategy: DownloadConflictStrategy.rename,
          mediaFilter: DownloadMediaFilter.all,
          directoryMode: DownloadDirectoryMode.flat,
        ),
      ),
      sync: const NoopDownloadSyncPort(),
    )..onInit();
    addTearDown(controller.onClose);
    await tester.pump();
    expect(sessions.loadCalls, 0);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DownloadWorkbenchScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(sessions.loadCalls, 1);
    expect(controller.chats, hasLength(1));
    expect(controller.chats.single.id, 1);
    expect(controller.chats.single.title, '会话一');
    controller.selectSourceChat(1);

    controller.chats.clear();
    sessions.availableChats = const [SelectableChat(id: 2, title: '会话二')];

    await tester.pumpWidget(
      const GetMaterialApp(home: SizedBox.shrink()),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: DownloadWorkbenchScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(sessions.loadCalls, 2);
    expect(controller.chats, hasLength(1));
    expect(controller.chats.single.id, 2);
    expect(controller.chats.single.title, '会话二');
    },
  );
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

class _MutableSessionGateway implements SessionQueryGateway {
  _MutableSessionGateway(this.availableChats);

  List<SelectableChat> availableChats;
  int loadCalls = 0;

  @override
  Future<List<SelectableChat>> listSelectableChats() async {
    loadCalls++;
    return availableChats;
  }
}
