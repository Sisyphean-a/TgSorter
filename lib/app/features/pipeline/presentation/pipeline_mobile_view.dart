import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_controller_legacy.dart';
import 'package:tgsorter/app/features/settings/application/settings_controller_legacy.dart';
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
      final currentMessage = pipeline.currentMessage.value;
      final videoPreparing = pipeline.videoPreparing.value;
      final canShowPrevious = pipeline.canShowPrevious.value;
      final canShowNext = pipeline.canShowNext.value;
      final online = pipeline.isOnline.value;
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
                        '${currentMessage?.sourceChatId}-${currentMessage?.id}-$processing',
                      ),
                      message: currentMessage,
                      processing: pipeline.loading.value || processing,
                      videoPreparing: videoPreparing,
                      onRequestMediaPlayback: pipeline.prepareCurrentMedia,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MobileActionTray(
                    key: ValueKey(
                      '${categories.length}-$online-$processing-$canShowNext-$canShowPrevious',
                    ),
                    categories: categories,
                    canClick: canClick,
                    online: online,
                    onClassify: pipeline.classify,
                    secondaryActions: Column(
                      key: const Key('mobile-secondary-actions'),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: !processing && canShowPrevious
                                    ? pipeline.showPreviousMessage
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
                                onPressed: !processing && canShowNext
                                    ? pipeline.showNextMessage
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
                                onPressed: canClick
                                    ? () =>
                                          pipeline.skipCurrent('mobile_button')
                                    : null,
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
                                onPressed: canClick
                                    ? pipeline.undoLastStep
                                    : null,
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
    });
  }
}
