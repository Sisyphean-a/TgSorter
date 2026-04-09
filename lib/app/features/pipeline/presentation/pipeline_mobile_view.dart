import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_coordinator.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/widgets/mobile_action_tray.dart';

class PipelineMobileView extends StatelessWidget {
  const PipelineMobileView({
    super.key,
    required this.pipeline,
    required this.settings,
  }) : vm = null,
       categories = const <CategoryConfig>[],
       onNavigateNext = null,
       onNavigatePrevious = null,
       onMediaAction = null,
       onClassify = null,
       onSkip = null,
       onUndo = null;

  const PipelineMobileView.fromVm({
    super.key,
    required this.vm,
    this.categories = const <CategoryConfig>[],
    required this.onNavigateNext,
    required this.onNavigatePrevious,
    required this.onMediaAction,
    required this.onClassify,
    required this.onSkip,
    required this.onUndo,
  }) : pipeline = null,
       settings = null;

  final PipelineCoordinator? pipeline;
  final PipelineSettingsReader? settings;
  final PipelineScreenVm? vm;
  final List<CategoryConfig> categories;
  final Future<void> Function()? onNavigateNext;
  final Future<void> Function()? onNavigatePrevious;
  final Future<void> Function(MediaAction action)? onMediaAction;
  final Future<bool> Function(String key)? onClassify;
  final Future<void> Function()? onSkip;
  final Future<void> Function()? onUndo;

  @override
  Widget build(BuildContext context) {
    if (pipeline == null) {
      return _buildBody(
        vm!,
        categories: categories,
        onNavigateNext: onNavigateNext!,
        onNavigatePrevious: onNavigatePrevious!,
        onMediaAction: onMediaAction!,
        onClassify: onClassify!,
        onSkip: onSkip!,
        onUndo: onUndo!,
      );
    }
    return Obx(() {
      return _buildBody(
        pipeline!.screenVm,
        categories: settings!.settingsStream.value.categories,
        onNavigateNext: pipeline!.showNextMessage,
        onNavigatePrevious: pipeline!.showPreviousMessage,
        onMediaAction: pipeline!.performMediaAction,
        onClassify: pipeline!.classify,
        onSkip: () => pipeline!.skipCurrent('mobile_button'),
        onUndo: pipeline!.undoLastStep,
      );
    });
  }

  Widget _buildBody(
    PipelineScreenVm vm, {
    required List<CategoryConfig> categories,
    required Future<void> Function() onNavigateNext,
    required Future<void> Function() onNavigatePrevious,
    required Future<void> Function(MediaAction action) onMediaAction,
    required Future<bool> Function(String key) onClassify,
    required Future<void> Function() onSkip,
    required Future<void> Function() onUndo,
  }) {
    final processing = vm.workflow.processingOverlay;
    final canClick = vm.workflow.online && !processing;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Focus(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          child: Padding(
            key: const Key('pipeline-mobile-layout'),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                Expanded(
                  key: const Key('mobile-message-pane'),
                  child: MessageViewerCard(
                    key: ValueKey(
                      '${vm.message.content?.sourceChatId}-${vm.message.content?.id}-$processing',
                    ),
                    vm: vm.message,
                    processing: processing,
                    onMediaAction: onMediaAction,
                  ),
                ),
                const SizedBox(height: 8),
                MobileActionTray(
                  key: ValueKey(
                    '${categories.length}-${vm.workflow.online}-$processing-${vm.navigation.canShowNext}-${vm.navigation.canShowPrevious}',
                  ),
                  categories: categories,
                  canClick: canClick,
                  online: vm.workflow.online,
                  onClassify: onClassify,
                  secondaryActions: Column(
                    key: const Key('mobile-secondary-actions'),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  !processing && vm.navigation.canShowPrevious
                                  ? onNavigatePrevious
                                  : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('上一条'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  !processing && vm.navigation.canShowNext
                                  ? onNavigateNext
                                  : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('下一条'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canClick ? onSkip : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('略过此条'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canClick ? onUndo : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(38),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('撤销上一步'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
