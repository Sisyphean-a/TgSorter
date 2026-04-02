import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/pages/settings_category_dialog.dart';
import 'package:tgsorter/app/pages/settings_page_parts.dart';
import 'package:tgsorter/app/pages/settings_sections.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/widgets/app_shell.dart';
import 'package:tgsorter/app/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/widgets/status_badge.dart';
import 'package:tgsorter/app/widgets/sticky_action_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsController controller = Get.find<SettingsController>();
  final PipelineController? pipeline = Get.isRegistered<PipelineController>()
      ? Get.find<PipelineController>()
      : null;

  @override
  void initState() {
    super.initState();
    _loadChats();
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final draft = controller.draftSettings.value;
      final saved = controller.savedSettings.value;
      return PopScope<void>(
        canPop: !controller.isDirty.value,
        onPopInvokedWithResult: _handlePopAttempt,
        child: AppShell(
          appBar: BrandAppBar(
            title: '分类设置',
            subtitle: '统一管理分类规则、连接配置和工具项',
            badges: [
              StatusBadge(
                label: controller.isDirty.value ? '草稿未保存' : '已保存',
                tone: controller.isDirty.value
                    ? StatusBadgeTone.warning
                    : StatusBadgeTone.success,
              ),
              StatusBadge(
                label: '分类 ${draft.categories.length}',
                tone: StatusBadgeTone.accent,
              ),
            ],
          ),
          bottomBar: StickyActionBar(
            isDirty: controller.isDirty.value,
            onDiscard: _handleDiscard,
            onSave: _handleSave,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (controller.isDirty.value)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SettingsUnsavedChangesBanner(),
                ),
              SettingsWorkflowSection(
                controller: controller,
                draft: draft,
                saved: saved,
              ),
              const SizedBox(height: 12),
              SettingsCategorySection(
                categories: draft.categories,
                savedCategories: saved.categories,
                chats: controller.chats.toList(growable: false),
                onAdd: _showAddCategoryDialog,
                onChanged: (key, chat) =>
                    controller.updateCategoryDraft(key: key, chat: chat),
                onRemove: _removeCategoryDraft,
              ),
              const SizedBox(height: 12),
              SettingsConnectionSection(
                controller: controller,
                draft: draft,
                saved: saved,
              ),
              const SizedBox(height: 12),
              SettingsToolsSection(
                controller: controller,
                draft: draft,
                saved: saved,
                recentLogs:
                    pipeline?.logs.take(20).toList(growable: false) ?? const [],
                onReloadChats: _loadChats,
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _handleSave() async {
    try {
      await controller.saveDraft();
      if (!mounted) {
        return;
      }
      _showMessage('设置已保存');
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
}
