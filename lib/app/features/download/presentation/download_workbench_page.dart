import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/download/application/download_workbench_controller.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class DownloadWorkbenchScreen extends StatefulWidget {
  const DownloadWorkbenchScreen({required this.controller, super.key});

  final DownloadWorkbenchController controller;

  @override
  State<DownloadWorkbenchScreen> createState() => _DownloadWorkbenchScreenState();
}

class _DownloadWorkbenchScreenState extends State<DownloadWorkbenchScreen> {
  late final TextEditingController _directoryController;

  DownloadWorkbenchController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _directoryController = TextEditingController(
      text: controller.targetDirectory.value,
    );
    unawaited(controller.loadChats());
  }

  @override
  void dispose() {
    _directoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final colors = AppTokens.colorsOf(context);
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '下载工作台',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            controller.activeSettings.value.downloadWorkbenchEnabled
                ? '选择来源和目标目录后会自动开始同步。'
                : '请先在 设置 > 下载 中启用下载工作台。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 16),
          const SettingsSectionHeader(title: '同步来源'),
          DropdownButtonFormField<int?>(
            initialValue: controller.selectedSourceChatId.value,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '来源会话'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('请选择来源会话'),
              ),
              ...controller.chats.map(
                (chat) => DropdownMenuItem<int?>(
                  value: chat.id,
                  child: Text(chat.title),
                ),
              ),
            ],
            onChanged: controller.activeSettings.value.downloadWorkbenchEnabled
                ? controller.selectSourceChat
                : null,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _directoryController,
            enabled: controller.activeSettings.value.downloadWorkbenchEnabled,
            onChanged: controller.updateTargetDirectory,
            decoration: const InputDecoration(labelText: '目标目录'),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.panelBackground,
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                controller.syncing.value
                    ? '同步中... 已扫描 ${controller.scannedMessages.value} 条'
                    : controller.lastError.value ??
                          controller.lastSummary.value,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '新增 ${controller.copiedFiles.value}  跳过 ${controller.skippedFiles.value}  清理 ${controller.deletedFiles.value}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      );
    });
  }
}
