import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_app_bar.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_screen.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({
    required this.controller,
    this.pipeline,
    SettingsNavigationController? navigation,
    super.key,
  }) : navigation = navigation ?? SettingsNavigationController();

  final SettingsCoordinator controller;
  final PipelineLogsPort? pipeline;
  final SettingsNavigationController navigation;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: SettingsAppBar(
        controller: controller,
        navigation: navigation,
        onSave: () => _handleSave(context),
      ),
      body: SettingsScreen(
        controller: controller,
        pipeline: pipeline,
        navigation: navigation,
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.saveDraft();
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('设置已保存')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }
}
