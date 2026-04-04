import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_desktop_view.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_mobile_view.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';

class PipelinePage extends StatelessWidget {
  const PipelinePage({
    required this.pipeline,
    required this.settings,
    required this.errors,
    super.key,
  });

  final PipelineCoordinator pipeline;
  final SettingsCoordinator settings;
  final AppErrorController errors;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remainingText = pipeline.remainingCountLoading.value
          ? '剩余 统计中'
          : '剩余 ${pipeline.remainingCount.value ?? '-'}';
      return AppShell(
        appBar: _PipelineCompactAppBar(
          remainingText: remainingText,
          onOpenSettings: () => Get.toNamed(AppRoutes.settings),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AppErrorPanel(controller: errors),
            ),
            Expanded(
              child: PipelineLayoutSwitch(
                mobile: PipelineMobileView(
                  pipeline: pipeline,
                  settings: settings,
                ),
                desktop: PipelineDesktopView(
                  pipeline: pipeline,
                  settings: settings,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PipelineCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _PipelineCompactAppBar({
    required this.remainingText,
    required this.onOpenSettings,
  });

  final String remainingText;
  final VoidCallback onOpenSettings;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppTokens.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'TgSorter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(label: remainingText, tone: StatusBadgeTone.accent),
                const SizedBox(width: 2),
                IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: '打开设置',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
