import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/pages/pipeline_log_formatter.dart';
import 'package:tgsorter/app/widgets/message_viewer_card.dart';

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
      final retryCount = pipeline.retryQueue.length;
      final latestLogs = pipeline.logs.take(5).toList(growable: false);
      return Padding(
        key: const Key('pipeline-mobile-layout'),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: MessageViewerCard(
                message: pipeline.currentMessage.value,
                processing: pipeline.loading.value || processing,
                videoPreparing: pipeline.videoPreparing.value,
                onRequestVideoPlayback: pipeline.prepareCurrentVideo,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!pipeline.isOnline.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '当前网络不可用，分类按钮已禁用',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('暂无分类，请先到设置页新增'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in categories)
                          SizedBox(
                            width: 150,
                            child: ElevatedButton(
                              onPressed: canClick
                                  ? () => pipeline.classify(category.key)
                                  : null,
                              child: Text(category.targetChatTitle),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: Text('失败重试队列：$retryCount')),
                      ElevatedButton(
                        onPressed:
                            canClick && retryCount > 0 ? pipeline.retryNextFailed : null,
                        child: const Text('重试下一条'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: latestLogs.length,
                        itemBuilder: (context, index) {
                          final item = latestLogs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              formatPipelineLog(item),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
