import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/pages/settings_category_dialog.dart';
import 'package:tgsorter/app/pages/settings_page_parts.dart';
import 'package:tgsorter/app/pages/settings_sections.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsController controller = Get.find<SettingsController>();

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
        child: Scaffold(
          appBar: AppBar(title: const Text('分类设置')),
          bottomNavigationBar: SettingsPageActions(
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
              const SizedBox(height: 8),
              SettingsCategorySection(
                categories: draft.categories,
                savedCategories: saved.categories,
                chats: controller.chats.toList(growable: false),
                onAdd: _showAddCategoryDialog,
                onChanged: (key, chat) =>
                    controller.updateCategoryDraft(key: key, chat: chat),
                onRemove: _removeCategoryDraft,
              ),
              const SizedBox(height: 8),
              SettingsConnectionSection(
                controller: controller,
                draft: draft,
                saved: saved,
              ),
              const SizedBox(height: 8),
              SettingsToolsSection(
                controller: controller,
                draft: draft,
                saved: saved,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
