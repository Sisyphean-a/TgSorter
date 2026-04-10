import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_category_dialog.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_group_section.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_sections.dart';
import 'package:tgsorter/app/shared/presentation/widgets/sticky_action_bar.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, this.pipeline, super.key});

  final SettingsCoordinator controller;
  final PipelineLogsPort? pipeline;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsCoordinator get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final draft = controller.draftSettings.value;
      final saved = controller.savedSettings.value;
      return PopScope<void>(
        canPop: !controller.isDirty.value,
        onPopInvokedWithResult: _handlePopAttempt,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (controller.isDirty.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SettingsUnsavedChangesBanner(),
                    ),
                  SettingsGroupSection(
                    key: const ValueKey('settings-section-workflow'),
                    title: '工作流',
                    subtitle: '消息来源、拉取方向和批处理节奏。',
                    highlighted: _workflowDirty(draft, saved),
                    child: SettingsWorkflowContent(
                      controller: controller,
                      draft: draft,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupSection(
                    key: const ValueKey('settings-section-category'),
                    title: '分类',
                    subtitle: '维护分类目标与目标会话映射。',
                    highlighted: !_sameCategories(
                      draft.categories,
                      saved.categories,
                    ),
                    initiallyExpanded: true,
                    child: SettingsCategoryContent(
                      categories: draft.categories,
                      savedCategories: saved.categories,
                      chats: controller.chats.toList(growable: false),
                      onAdd: _showAddCategoryDialog,
                      onChanged: (key, chat) =>
                          controller.updateCategoryDraft(key: key, chat: chat),
                      onRemove: _removeCategoryDraft,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupSection(
                    key: const ValueKey('settings-section-connection'),
                    title: '连接与代理',
                    subtitle: '代理配置保存后统一生效，并在必要时重启连接。',
                    highlighted: draft.proxy != saved.proxy,
                    child: SettingsConnectionContent(
                      controller: controller,
                      draft: draft,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SettingsGroupSection(
                    key: const ValueKey('settings-section-tools'),
                    title: '快捷键与工具',
                    subtitle: '刷新会话列表并维护桌面端快捷键。',
                    highlighted:
                        draft.shortcutBindings != saved.shortcutBindings,
                    child: SettingsToolsContent(
                      controller: controller,
                      draft: draft,
                      onReloadChats: _loadChats,
                    ),
                  ),
                ],
              ),
            ),
            StickyActionBar(
              isDirty: controller.isDirty.value,
              onDiscard: _handleDiscard,
              onSave: _handleSave,
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadChats() async {
    try {
      await controller.loadChats();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('加载会话失败：$error');
    }
  }

  Future<void> _handleSave() async {
    try {
      final result = await controller.saveDraft();
      if (!mounted) {
        return;
      }
      switch (result) {
        case SettingsSaveResult.saved:
        case SettingsSaveResult.savedAndRestarted:
          _showMessage('设置已保存');
          break;
        case SettingsSaveResult.savedNeedsRestartAttention:
          _showMessage('设置已保存，但重启失败，请稍后手动重试。');
          break;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('保存失败：$error');
    }
  }

  Future<void> _handleDiscard() async {
    if (!controller.isDirty.value) {
      return;
    }
    final shouldDiscard = await _confirmDiscard();
    if (!shouldDiscard) {
      return;
    }
    controller.discardDraft();
    if (!mounted) {
      return;
    }
    _showMessage('已放弃未保存更改');
  }

  Future<void> _showAddCategoryDialog() async {
    final availableChats = _availableCategoryChats();
    await showDialog<void>(
      context: context,
      builder: (_) => AddCategoryDialog(
        chats: availableChats,
        onAdd: (chat) {
          try {
            controller.addCategoryDraft(chat);
          } catch (error) {
            _showMessage(error.toString());
          }
        },
      ),
    );
  }

  Future<void> _removeCategoryDraft(String key) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除分类'),
        content: const Text('这会从当前草稿中移除该分类，保存后才会真正生效。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    controller.removeCategoryDraft(key);
  }

  Future<void> _handlePopAttempt(bool didPop, void _) async {
    if (didPop || !controller.isDirty.value) {
      return;
    }
    final confirmed = await _confirmDiscard();
    if (!mounted || !confirmed) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('放弃更改'),
        content: const Text('离开或放弃后，当前未保存的修改都会丢失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  List<SelectableChat> _availableCategoryChats() {
    final usedIds = controller.draftSettings.value.categories
        .map((item) => item.targetChatId)
        .toSet();
    return controller.chats
        .where((item) => !usedIds.contains(item.id))
        .toList(growable: false);
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  bool _sameCategories(List<CategoryConfig> left, List<CategoryConfig> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _workflowDirty(AppSettings current, AppSettings original) {
    return current.sourceChatId != original.sourceChatId ||
        current.fetchDirection != original.fetchDirection ||
        current.forwardAsCopy != original.forwardAsCopy ||
        current.batchSize != original.batchSize ||
        current.throttleMs != original.throttleMs ||
        current.previewPrefetchCount != original.previewPrefetchCount;
  }
}
