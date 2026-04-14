import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_desktop_view.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_mobile_view.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_recovery_panel.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';

class PipelineScreen extends StatelessWidget {
  const PipelineScreen({
    required this.pipeline,
    required this.settings,
    required this.errors,
    super.key,
  });

  final PipelineCoordinator pipeline;
  final PipelineSettingsReader settings;
  final AppErrorController errors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              PipelineRecoveryPanel(pipeline: pipeline),
              AppErrorPanel(controller: errors),
            ],
          ),
        ),
        Expanded(
          child: PipelineLayoutSwitch(
            mobile: PipelineMobileView(pipeline: pipeline, settings: settings),
            desktop: PipelineDesktopView(
              pipeline: pipeline,
              settings: settings,
            ),
          ),
        ),
      ],
    );
  }
}

class PipelineCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PipelineCompactAppBar({
    required this.pipeline,
    this.leading,
    super.key,
  });

  final PipelineCoordinator pipeline;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remainingText = pipeline.remainingCountLoading.value
          ? '剩余 统计中'
          : '剩余 ${pipeline.remainingCount.value ?? '-'}';
      final theme = Theme.of(context);
      final colors = AppTokens.colorsOf(context);
      return Material(
        color: colors.pageBackground,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 4)],
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
                  StatusBadge(
                    label: remainingText,
                    tone: StatusBadgeTone.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
