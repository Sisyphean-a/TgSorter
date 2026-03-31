import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
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
                        child: Text('当前网络不可用，按钮已禁用', style: TextStyle(color: Colors.red)),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          for (final category in categories)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  onPressed: canClick ? () => pipeline.classify(category.key) : null,
                                  child: Text(category.name),
                                ),
                              ),
                            ),
                        ],
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
}
