import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/features/pipeline/presentation/pipeline_desktop_panels.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/shared/presentation/widgets/workspace_panel.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';

class MessageWorkbenchView extends StatelessWidget {
  const MessageWorkbenchView({
    super.key,
    required this.vm,
    required this.actionArea,
    required this.directionText,
    required this.onNavigatePrevious,
    required this.onNavigateNext,
    required this.onSkip,
    required this.onMediaAction,
  });

  final PipelineScreenVm vm;
  final Widget actionArea;
  final String directionText;
  final Future<void> Function() onNavigatePrevious;
  final Future<void> Function() onNavigateNext;
  final Future<void> Function() onSkip;
  final Future<void> Function(MediaAction action) onMediaAction;

  @override
  Widget build(BuildContext context) {
    return PipelineLayoutSwitch(
      mobile: _MobileWorkbench(
        vm: vm,
        actionArea: actionArea,
        onNavigatePrevious: onNavigatePrevious,
        onNavigateNext: onNavigateNext,
        onSkip: onSkip,
        onMediaAction: onMediaAction,
      ),
      desktop: _DesktopWorkbench(
        vm: vm,
        actionArea: actionArea,
        directionText: directionText,
        onNavigatePrevious: onNavigatePrevious,
        onNavigateNext: onNavigateNext,
        onSkip: onSkip,
        onMediaAction: onMediaAction,
      ),
    );
  }
}

class _DesktopWorkbench extends StatelessWidget {
  const _DesktopWorkbench({
    required this.vm,
    required this.actionArea,
    required this.directionText,
    required this.onNavigatePrevious,
    required this.onNavigateNext,
    required this.onSkip,
    required this.onMediaAction,
  });

  final PipelineScreenVm vm;
  final Widget actionArea;
  final String directionText;
  final Future<void> Function() onNavigatePrevious;
  final Future<void> Function() onNavigateNext;
  final Future<void> Function() onSkip;
  final Future<void> Function(MediaAction action) onMediaAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('tagging-workbench-desktop'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(flex: 70, child: _messagePane(vm, actionArea)),
          const SizedBox(width: 16),
          Expanded(flex: 30, child: _sidePane()),
        ],
      ),
    );
  }

  Widget _messagePane(PipelineScreenVm vm, Widget actionArea) {
    return WorkspacePanel(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _messageCard(vm, embedded: true)),
          const SizedBox(height: 12),
          actionArea,
        ],
      ),
    );
  }

  Widget _sidePane() {
    return WorkspacePanel(
      dense: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesktopStatusBar(
            online: vm.workflow.online,
            processing: vm.workflow.processingOverlay,
            directionText: directionText,
          ),
          const SizedBox(height: 12),
          DesktopMessageSummary(message: vm.message),
          const SizedBox(height: 12),
          _WorkbenchBrowseButtons(
            vm: vm,
            onNavigatePrevious: onNavigatePrevious,
            onNavigateNext: onNavigateNext,
            onSkip: onSkip,
          ),
        ],
      ),
    );
  }

  Widget _messageCard(PipelineScreenVm vm, {required bool embedded}) {
    return MessageViewerCard(
      key: ValueKey(
        '${vm.message.content?.sourceChatId}-${vm.message.content?.id}-${vm.workflow.processingOverlay}',
      ),
      vm: vm.message,
      processing: vm.workflow.processingOverlay,
      embedded: embedded,
      onMediaAction: onMediaAction,
    );
  }
}

class _MobileWorkbench extends StatelessWidget {
  const _MobileWorkbench({
    required this.vm,
    required this.actionArea,
    required this.onNavigatePrevious,
    required this.onNavigateNext,
    required this.onSkip,
    required this.onMediaAction,
  });

  final PipelineScreenVm vm;
  final Widget actionArea;
  final Future<void> Function() onNavigatePrevious;
  final Future<void> Function() onNavigateNext;
  final Future<void> Function() onSkip;
  final Future<void> Function(MediaAction action) onMediaAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('tagging-workbench-mobile'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          Expanded(child: _messageCard()),
          const SizedBox(height: 8),
          _mobileActions(),
        ],
      ),
    );
  }

  Widget _messageCard() {
    return MessageViewerCard(
      key: ValueKey(
        '${vm.message.content?.sourceChatId}-${vm.message.content?.id}-${vm.workflow.processingOverlay}',
      ),
      vm: vm.message,
      processing: vm.workflow.processingOverlay,
      onMediaAction: onMediaAction,
    );
  }

  Widget _mobileActions() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            actionArea,
            const SizedBox(height: 6),
            _WorkbenchBrowseButtons(
              vm: vm,
              onNavigatePrevious: onNavigatePrevious,
              onNavigateNext: onNavigateNext,
              onSkip: onSkip,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbenchBrowseButtons extends StatelessWidget {
  const _WorkbenchBrowseButtons({
    required this.vm,
    required this.onNavigatePrevious,
    required this.onNavigateNext,
    required this.onSkip,
  });

  final PipelineScreenVm vm;
  final Future<void> Function() onNavigatePrevious;
  final Future<void> Function() onNavigateNext;
  final Future<void> Function() onSkip;

  @override
  Widget build(BuildContext context) {
    final canBrowse = !vm.workflow.processingOverlay;
    final canClick = vm.workflow.online && !vm.workflow.processingOverlay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: canBrowse && vm.navigation.canShowPrevious
                    ? onNavigatePrevious
                    : null,
                child: const Text('上一条'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: canBrowse && vm.navigation.canShowNext
                    ? onNavigateNext
                    : null,
                child: const Text('下一条'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: canClick ? onSkip : null,
          child: const Text('略过此条'),
        ),
      ],
    );
  }
}
