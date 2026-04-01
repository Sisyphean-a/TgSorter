import 'package:flutter/material.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/pages/pipeline_log_formatter.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Text('网络：$onlineText'),
            const SizedBox(width: 12),
            Text('状态：$processingText'),
            const SizedBox(width: 12),
            Text('拉取：$directionText'),
          ],
        ),
      ),
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
              Text('${labelShortcutAction(action)}: ${labelShortcutBinding(bindings[action])}'),
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
                    onPressed: canClick ? pipeline.skipCurrent : null,
                    child: const Text('跳过当前'),
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

class DesktopRetryCard extends StatelessWidget {
  const DesktopRetryCard({
    super.key,
    required this.retryCount,
    required this.canClick,
    required this.onRetry,
  });

  final int retryCount;
  final bool canClick;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: Text('失败重试队列：$retryCount')),
            ElevatedButton(
              onPressed: canClick && retryCount > 0 ? onRetry : null,
              child: const Text('重试下一条'),
            ),
          ],
        ),
      ),
    );
  }
}

class DesktopLogsCard extends StatelessWidget {
  const DesktopLogsCard({super.key, required this.logs});

  final List<ClassifyOperationLog> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('最近日志', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      formatPipelineLog(logs[index]),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
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
      return '跳过当前';
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
