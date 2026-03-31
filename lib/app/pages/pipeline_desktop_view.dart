import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/pages/pipeline_desktop_panels.dart';
import 'package:tgsorter/app/widgets/message_viewer_card.dart';

class PipelineDesktopView extends StatelessWidget {
  const PipelineDesktopView({
    super.key,
    required this.pipeline,
    required this.settings,
  });

  final PipelineController pipeline;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final shortcuts = _buildShortcutsMap();
      return Shortcuts(
        shortcuts: shortcuts,
        child: Actions(actions: _buildActionMap(), child: _buildBody()),
      );
    });
  }

  Widget _buildBody() {
    final processing = pipeline.processing.value;
    final canClick = pipeline.isOnline.value && !processing;
    return Padding(
      key: const Key('pipeline-desktop-layout'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(flex: 65, child: _buildLeftPane(processing, canClick)),
          const SizedBox(width: 16),
          Expanded(flex: 35, child: _buildRightPane(canClick)),
        ],
      ),
    );
  }

  Widget _buildLeftPane(bool processing, bool canClick) {
    final categories = settings.settings.value.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopStatusBar(
          online: pipeline.isOnline.value,
          processing: processing,
          directionText: settings.settings.value.fetchDirection.name,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: MessageViewerCard(
            message: pipeline.currentMessage.value,
            processing: pipeline.loading.value || processing,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final category in categories)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed:
                          canClick ? () => pipeline.classify(category.key) : null,
                      child: Text(category.name),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightPane(bool canClick) {
    final latestLogs = pipeline.logs.take(20).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesktopShortcutCard(bindings: settings.settings.value.shortcutBindings),
        const SizedBox(height: 10),
        DesktopActionButtons(pipeline: pipeline, canClick: canClick),
        const SizedBox(height: 10),
        DesktopRetryCard(
          retryCount: pipeline.retryQueue.length,
          canClick: canClick,
          onRetry: pipeline.retryNextFailed,
        ),
        const SizedBox(height: 10),
        Expanded(child: DesktopLogsCard(logs: latestLogs)),
      ],
    );
  }

  Map<ShortcutActivator, Intent> _buildShortcutsMap() {
    final result = <ShortcutActivator, Intent>{};
    for (final action in ShortcutAction.values) {
      final binding = settings.settings.value.shortcutBindings[action];
      if (binding == null) {
        continue;
      }
      result[SingleActivator(
        _logicalKeyFor(binding.trigger),
        control: binding.ctrl,
      )] = _intentForAction(action);
    }
    return result;
  }

  Map<Type, Action<Intent>> _buildActionMap() {
    return {
      _ClassifyAIntent: CallbackAction<_ClassifyAIntent>(
        onInvoke: (_) => _fire(() => pipeline.classify('a')),
      ),
      _ClassifyBIntent: CallbackAction<_ClassifyBIntent>(
        onInvoke: (_) => _fire(() => pipeline.classify('b')),
      ),
      _ClassifyCIntent: CallbackAction<_ClassifyCIntent>(
        onInvoke: (_) => _fire(() => pipeline.classify('c')),
      ),
      _SkipIntent: CallbackAction<_SkipIntent>(
        onInvoke: (_) => _fire(pipeline.skipCurrent),
      ),
      _UndoIntent: CallbackAction<_UndoIntent>(
        onInvoke: (_) => _fire(pipeline.undoLastStep),
      ),
      _RetryIntent: CallbackAction<_RetryIntent>(
        onInvoke: (_) => _fire(pipeline.retryNextFailed),
      ),
      _BatchAIntent: CallbackAction<_BatchAIntent>(
        onInvoke: (_) => _fire(() => pipeline.runBatch('a')),
      ),
    };
  }

  Intent _intentForAction(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.classifyA:
        return const _ClassifyAIntent();
      case ShortcutAction.classifyB:
        return const _ClassifyBIntent();
      case ShortcutAction.classifyC:
        return const _ClassifyCIntent();
      case ShortcutAction.skipCurrent:
        return const _SkipIntent();
      case ShortcutAction.undoLastStep:
        return const _UndoIntent();
      case ShortcutAction.retryNextFailed:
        return const _RetryIntent();
      case ShortcutAction.batchA:
        return const _BatchAIntent();
    }
  }

  LogicalKeyboardKey _logicalKeyFor(ShortcutTrigger trigger) {
    switch (trigger) {
      case ShortcutTrigger.digit1:
        return LogicalKeyboardKey.digit1;
      case ShortcutTrigger.digit2:
        return LogicalKeyboardKey.digit2;
      case ShortcutTrigger.digit3:
        return LogicalKeyboardKey.digit3;
      case ShortcutTrigger.keyS:
        return LogicalKeyboardKey.keyS;
      case ShortcutTrigger.keyZ:
        return LogicalKeyboardKey.keyZ;
      case ShortcutTrigger.keyR:
        return LogicalKeyboardKey.keyR;
      case ShortcutTrigger.keyB:
        return LogicalKeyboardKey.keyB;
    }
  }

  Object? _fire(Future<void> Function() work) {
    unawaited(work());
    return null;
  }
}

class _ClassifyAIntent extends Intent {
  const _ClassifyAIntent();
}

class _ClassifyBIntent extends Intent {
  const _ClassifyBIntent();
}

class _ClassifyCIntent extends Intent {
  const _ClassifyCIntent();
}

class _SkipIntent extends Intent {
  const _SkipIntent();
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RetryIntent extends Intent {
  const _RetryIntent();
}

class _BatchAIntent extends Intent {
  const _BatchAIntent();
}
