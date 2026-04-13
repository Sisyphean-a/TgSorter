import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_screen.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

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
      appBar: SettingsCompactAppBar(
        controller: controller,
        navigation: navigation,
      ),
      body: SettingsScreen(
        controller: controller,
        pipeline: pipeline,
        navigation: navigation,
      ),
    );
  }
}

class SettingsCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const SettingsCompactAppBar({
    required this.controller,
    required this.navigation,
    this.title,
    this.leading,
    super.key,
  });

  final SettingsCoordinator controller;
  final SettingsNavigationController navigation;
  final String? title;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final theme = Theme.of(context);
      final colors = AppTokens.colorsOf(context);
      final dirty = controller.isDirty.value;
      final canPop = navigation.canPop.value;
      final resolvedTitle = title ?? navigation.currentTitle;
      return Material(
        color: colors.pageBackground,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    onPressed: navigation.backToHome,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: '返回',
                  )
                else if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    resolvedTitle,
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
