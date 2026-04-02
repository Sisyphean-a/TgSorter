import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/pages/pipeline_desktop_view.dart';
import 'package:tgsorter/app/pages/pipeline_mobile_view.dart';
import 'package:tgsorter/app/widgets/app_error_panel.dart';
import 'package:tgsorter/app/widgets/app_shell.dart';
import 'package:tgsorter/app/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';
import 'package:tgsorter/app/widgets/status_badge.dart';

class PipelinePage extends StatelessWidget {
  PipelinePage({super.key});

  final PipelineController pipeline = Get.find<PipelineController>();
  final SettingsController settings = Get.find<SettingsController>();
  final AppErrorController errors = Get.find<AppErrorController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final remainingText = pipeline.remainingCountLoading.value
          ? '剩余 统计中'
          : '剩余 ${pipeline.remainingCount.value ?? '-'}';
      final onlineTone = pipeline.isOnline.value
          ? StatusBadgeTone.success
          : StatusBadgeTone.danger;
      final processTone = pipeline.processing.value
          ? StatusBadgeTone.warning
          : StatusBadgeTone.neutral;
      final statusText = pipeline.processing.value ? '处理中' : '待命';
      return AppShell(
        appBar: BrandAppBar(
          title: 'TgSorter',
          subtitle: '分类工作台',
          badges: [
            StatusBadge(
              label: pipeline.isOnline.value ? '在线' : '离线',
              tone: onlineTone,
            ),
            StatusBadge(label: statusText, tone: processTone),
            StatusBadge(label: remainingText, tone: StatusBadgeTone.accent),
          ],
          actions: [
            IconButton(
              onPressed: () => Get.toNamed('/settings'),
              icon: const Icon(Icons.tune_rounded),
              tooltip: '打开设置',
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
    });
  }
}
