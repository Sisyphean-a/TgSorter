import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';

class DesktopStatusBar extends StatelessWidget {
  const DesktopStatusBar({
    super.key,
    required this.online,
    required this.processing,
    required this.directionText,
  });

  final bool online;
  final bool processing;
  final String directionText;

  @override
  Widget build(BuildContext context) {
    final onlineText = online ? '在线' : '离线';
    final processingText = processing ? '处理中' : '空闲';
    final directionLabel = directionText == 'latestFirst' ? '最新优先' : '最旧优先';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusBadge(
          label: onlineText,
          tone: online ? StatusBadgeTone.success : StatusBadgeTone.danger,
        ),
        StatusBadge(
          label: processingText,
          tone: processing ? StatusBadgeTone.warning : StatusBadgeTone.neutral,
        ),
        StatusBadge(label: '拉取 $directionLabel', tone: StatusBadgeTone.accent),
      ],
    );
  }
}

class DesktopActionButtons extends StatelessWidget {
  const DesktopActionButtons({
    super.key,
    required this.navigation,
    required this.workflow,
    required this.onNavigatePrevious,
    required this.onNavigateNext,
    required this.onSkip,
    required this.onUndo,
  });

  final NavigationVm navigation;
  final WorkflowVm workflow;
  final Future<void> Function() onNavigatePrevious;
  final Future<void> Function() onNavigateNext;
  final Future<void> Function() onSkip;
  final Future<void> Function() onUndo;

  @override
  Widget build(BuildContext context) {
    final canBrowse = !workflow.processingOverlay;
    final canClick = workflow.online && !workflow.processingOverlay;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canBrowse && navigation.canShowPrevious
                        ? onNavigatePrevious
                        : null,
                    child: const Text('上一条'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canBrowse && navigation.canShowNext
                        ? onNavigateNext
                        : null,
                    child: const Text('下一条'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canClick ? onSkip : null,
                    child: const Text('略过此条'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canClick ? onUndo : null,
                    child: const Text('撤销上一步'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
