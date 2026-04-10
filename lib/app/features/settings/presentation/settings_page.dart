import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_screen.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, this.pipeline, super.key});

  final SettingsCoordinator controller;
  final PipelineLogsPort? pipeline;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: SettingsCompactAppBar(controller: controller),
      body: SettingsScreen(controller: controller, pipeline: pipeline),
    );
  }
}

class SettingsCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SettingsCompactAppBar({
    required this.controller,
    this.title = '设置',
    this.leading,
    super.key,
  });

  final SettingsCoordinator controller;
  final String title;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = Theme.of(context);
      final dirty = controller.isDirty.value;
      return Material(
        color: AppTokens.pageBackground,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusBadge(
                  label: dirty ? '草稿未保存' : '已保存',
                  tone: dirty
                      ? StatusBadgeTone.warning
                      : StatusBadgeTone.success,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
