import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_desktop_panels.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/widgets/classification_action_group.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/shared/presentation/widgets/workspace_panel.dart';

const _desktopContentFlex = 70;
const _desktopSideFlex = 30;

class PipelineDesktopView extends StatelessWidget {
  const PipelineDesktopView({
    super.key,
    required this.pipeline,
    required this.settings,
  });

  final PipelineCoordinator pipeline;
  final PipelineSettingsReader settings;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final vm = pipeline.screenVm;
      final shortcuts = _buildShortcutsMap();
      return Shortcuts(
        shortcuts: shortcuts,
        child: Actions(actions: _buildActionMap(vm), child: _buildBody(vm)),
      );
    });
  }

  Widget _buildBody(PipelineScreenVm vm) {
    return Padding(
      key: const Key('pipeline-desktop-workspace'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(flex: _desktopContentFlex, child: _buildLeftPane(vm)),
          const SizedBox(width: 16),
          Expanded(flex: _desktopSideFlex, child: _buildRightPane(vm)),
        ],
      ),
    );
  }

  Widget _buildLeftPane(PipelineScreenVm vm) {
    final categories = settings.settingsStream.value.categories;
    return WorkspacePanel(
      key: const Key('desktop-message-panel'),
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: MessageViewerCard(
                key: ValueKey(
                  '${vm.message.content?.sourceChatId}-${vm.message.content?.id}-${vm.workflow.processingOverlay}',
                ),
                vm: vm.message,
                processing: vm.workflow.processingOverlay,
                embedded: true,
                onMediaAction: pipeline.performMediaAction,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ClassificationActionGroup(
            categories: categories,
            enabled: vm.workflow.online && !vm.workflow.processingOverlay,
            onClassify: pipeline.classify,
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane(PipelineScreenVm vm) {
    return WorkspacePanel(
      key: const Key('desktop-action-panel'),
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopStatusBar(
            online: vm.workflow.online,
            processing: vm.workflow.processingOverlay,
            directionText: settings.settingsStream.value.fetchDirection.name,
          ),
          const SizedBox(height: 12),
          DesktopMessageSummary(message: vm.message),
          const SizedBox(height: 12),
          DesktopActionButtons(
            key: const Key('desktop-operations-panel'),
            navigation: vm.navigation,
            workflow: vm.workflow,
            onNavigatePrevious: pipeline.showPreviousMessage,
            onNavigateNext: pipeline.showNextMessage,
            onSkip: () => pipeline.skipCurrent('desktop_button'),
            onUndo: pipeline.undoLastStep,
          ),
        ],
      ),
    );
  }

  Map<ShortcutActivator, Intent> _buildShortcutsMap() {
    final result = <ShortcutActivator, Intent>{};
    for (final action in ShortcutAction.values) {
      final binding = settings.settingsStream.value.shortcutBindings[action];
      if (binding == null) {
        continue;
      }
      result[SingleActivator(
        _logicalKeyFor(binding.trigger),
        control: binding.ctrl,
      )] = _intentForAction(
        action,
      );
    }
    return result;
  }

  Map<Type, Action<Intent>> _buildActionMap(PipelineScreenVm vm) {
    final canBrowse = !vm.workflow.processingOverlay;
    final canClick = vm.workflow.online && !vm.workflow.processingOverlay;
    return {
      _PreviousIntent: CallbackAction<_PreviousIntent>(
        onInvoke: (_) => canBrowse && vm.navigation.canShowPrevious
            ? _fire(pipeline.showPreviousMessage)
            : null,
      ),
      _NextIntent: CallbackAction<_NextIntent>(
        onInvoke: (_) => canBrowse && vm.navigation.canShowNext
            ? _fire(pipeline.showNextMessage)
            : null,
      ),
      _SkipIntent: CallbackAction<_SkipIntent>(
        onInvoke: (_) => canClick
            ? _fire(() => pipeline.skipCurrent('desktop_shortcut'))
            : null,
      ),
      _UndoIntent: CallbackAction<_UndoIntent>(
        onInvoke: (_) => canClick ? _fire(pipeline.undoLastStep) : null,
      ),
      _RetryIntent: CallbackAction<_RetryIntent>(
        onInvoke: (_) => canClick ? _fire(pipeline.retryNextFailed) : null,
      ),
    };
  }

  Intent _intentForAction(ShortcutAction action) {
    switch (action) {
      case ShortcutAction.previousMessage:
        return const _PreviousIntent();
      case ShortcutAction.nextMessage:
        return const _NextIntent();
      case ShortcutAction.skipCurrent:
        return const _SkipIntent();
      case ShortcutAction.undoLastStep:
        return const _UndoIntent();
      case ShortcutAction.retryNextFailed:
        return const _RetryIntent();
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

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
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
