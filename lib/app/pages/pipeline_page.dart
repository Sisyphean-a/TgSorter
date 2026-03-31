import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/widgets/message_viewer_card.dart';

class PipelinePage extends StatelessWidget {
  PipelinePage({super.key});

  final PipelineController pipeline = Get.find<PipelineController>();
  final SettingsController settings = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TgSorter 分发流水线'),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Obx(() {
        final categories = settings.settings.value.categories;
        final processing = pipeline.processing.value;
        final canClick = pipeline.isOnline.value && !processing;
        final retryCount = pipeline.retryQueue.length;
        final latestLogs = pipeline.logs.take(5).toList(growable: false);

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: MessageViewerCard(
                  message: pipeline.currentMessage.value,
                  processing: pipeline.loading.value || processing,
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
                          '当前网络不可用，按钮已禁用',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          for (final category in categories)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ElevatedButton(
                                  onPressed: canClick
                                      ? () => pipeline.classify(category.key)
                                      : null,
                                  child: Text(category.name),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('失败重试队列：$retryCount')),
                        ElevatedButton(
                          onPressed: canClick && retryCount > 0
                              ? pipeline.retryNextFailed
                              : null,
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
                                _formatLog(item),
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
      }),
    );
  }

  String _formatLog(ClassifyOperationLog log) {
    final time = DateTime.fromMillisecondsSinceEpoch(log.createdAtMs);
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    final status = _labelStatus(log.status);
    final suffix = log.reason == null ? '' : ' ${log.reason}';
    return '[$hh:$mm:$ss] $status m:${log.messageId} -> ${log.targetChatId}$suffix';
  }

  String _labelStatus(ClassifyOperationStatus status) {
    switch (status) {
      case ClassifyOperationStatus.success:
        return '成功';
      case ClassifyOperationStatus.failed:
        return '失败';
      case ClassifyOperationStatus.retrySuccess:
        return '重试成功';
      case ClassifyOperationStatus.retryFailed:
        return '重试失败';
    }
  }
}
