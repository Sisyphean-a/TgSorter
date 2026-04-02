import 'package:flutter/material.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/widgets/status_badge.dart';

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

class DesktopShortcutCard extends StatelessWidget {
  const DesktopShortcutCard({super.key, required this.bindings});

  final Map<ShortcutAction, ShortcutBinding> bindings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快捷键映射', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            for (final action in ShortcutAction.values)
              Text(
                '${labelShortcutAction(action)}: ${labelShortcutBinding(bindings[action])}',
              ),
          ],
        ),
      ),
    );
  }
}

class DesktopActionButtons extends StatelessWidget {
  const DesktopActionButtons({
    super.key,
    required this.pipeline,
    required this.canClick,
  });

  final PipelineController pipeline;
  final bool canClick;

  @override
  Widget build(BuildContext context) {
    final canBrowse = !pipeline.processing.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('控制台', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canBrowse && pipeline.canShowPrevious.value
                        ? pipeline.showPreviousMessage
                        : null,
                    child: const Text('上一条'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canBrowse && pipeline.canShowNext.value
                        ? pipeline.showNextMessage
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
                    onPressed: canClick
                        ? () => pipeline.skipCurrent('desktop_button')
                        : null,
                    child: const Text('略过此条'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: canClick ? pipeline.undoLastStep : null,
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

String labelShortcutAction(ShortcutAction action) {
  switch (action) {
    case ShortcutAction.previousMessage:
      return '上一条';
    case ShortcutAction.nextMessage:
      return '下一条';
    case ShortcutAction.skipCurrent:
      return '略过此条';
    case ShortcutAction.undoLastStep:
      return '撤销上一步';
    case ShortcutAction.retryNextFailed:
      return '重试下一条';
  }
}

String labelShortcutBinding(ShortcutBinding? binding) {
  if (binding == null) {
    return '-';
  }
  final key = binding.trigger.name
      .replaceFirst('digit', '')
      .replaceFirst('key', '')
      .toUpperCase();
  if (binding.ctrl) {
    return 'Ctrl+$key';
  }
  return key;
}
