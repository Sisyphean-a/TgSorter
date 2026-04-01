import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/pages/pipeline_desktop_view.dart';
import 'package:tgsorter/app/pages/pipeline_mobile_view.dart';
import 'package:tgsorter/app/widgets/app_error_panel.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';

class PipelinePage extends StatelessWidget {
  PipelinePage({super.key});

  final PipelineController pipeline = Get.find<PipelineController>();
  final SettingsController settings = Get.find<SettingsController>();
  final AppErrorController errors = Get.find<AppErrorController>();

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppErrorPanel(controller: errors),
          ),
          Expanded(
            child: PipelineLayoutSwitch(
              mobile: PipelineMobileView(
                pipeline: pipeline,
                settings: settings,
              ),
              desktop: PipelineDesktopView(
                pipeline: pipeline,
                settings: settings,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
