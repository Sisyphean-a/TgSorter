import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/widgets/mobile_action_tray.dart';

class PipelineMobileView extends StatelessWidget {
  const PipelineMobileView({
    super.key,
    required this.pipeline,
    required this.settings,
  });

  final PipelineController pipeline;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final categories = settings.settings.value.categories;
      final processing = pipeline.processing.value;
      final canClick = pipeline.isOnline.value && !processing;
      return Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Padding(
          key: const Key('pipeline-mobile-layout'),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                key: const Key('mobile-message-pane'),
                flex: 6,
                child: MessageViewerCard(
                  key: ValueKey(
                    '${pipeline.currentMessage.value?.sourceChatId}-${pipeline.currentMessage.value?.id}',
                  ),
                  message: pipeline.currentMessage.value,
                  processing: pipeline.loading.value || processing,
                  videoPreparing: pipeline.videoPreparing.value,
                  onRequestMediaPlayback: pipeline.prepareCurrentMedia,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 4,
                child: MobileActionTray(
                  categories: categories,
                  canClick: canClick,
                  online: pipeline.isOnline.value,
                  onClassify: pipeline.classify,
                  secondaryActions: Column(
                    key: const Key('mobile-secondary-actions'),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  !processing && pipeline.canShowPrevious.value
                                  ? pipeline.showPreviousMessage
                                  : null,
                              child: const Text('上一条'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  !processing && pipeline.canShowNext.value
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
                                  ? () => pipeline.skipCurrent('mobile_button')
                                  : null,
                              child: const Text('略过此条'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: canClick
                                  ? pipeline.undoLastStep
                                  : null,
                              child: const Text('撤销上一步'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
