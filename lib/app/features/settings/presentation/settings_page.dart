import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/application/settings_page_draft_session.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_app_bar.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_screen.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({
    required this.controller,
    this.pipeline,
    SettingsNavigationController? navigation,
    SettingsPageDraftSession? draftSession,
    super.key,
  }) : navigation = navigation ?? SettingsNavigationController(),
       draftSession = draftSession ?? SettingsPageDraftSession();

  final SettingsCoordinator controller;
  final PipelineLogsPort? pipeline;
  final SettingsNavigationController navigation;
  final SettingsPageDraftSession draftSession;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: SettingsAppBar(
        draftSession: draftSession,
        navigation: navigation,
        onSave: () => _handleSave(context),
      ),
      body: SettingsScreen(
        controller: controller,
        pipeline: pipeline,
        navigation: navigation,
        draftSession: draftSession,
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await controller.savePageDraft(draftSession.draftSettings.value);
      draftSession.markSaved(controller.savedSettings.value);
      if (!context.mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(_saveMessage(result))));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  String _saveMessage(SettingsSaveResult result) {
    switch (result) {
      case SettingsSaveResult.saved:
      case SettingsSaveResult.savedAndRestarted:
        return '设置已保存';
      case SettingsSaveResult.savedNeedsRestartAttention:
        return '设置已保存，但重启失败，请稍后手动重试。';
    }
  }
}
