import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_save_result.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_category_dialog.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_list_section.dart';
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  if (controller.isDirty.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: SettingsUnsavedChangesBanner(),
                    ),
                  SettingsListSection(
                    key: const ValueKey('settings-section-forwarding'),
                    title: '转发区设置',
                    highlighted: _forwardingDirty(draft, saved),
                    children: [
                      SettingsForwardingContent(
                        controller: controller,
                        draft: draft,
                        saved: saved,
                        onAddCategory: _showAddCategoryDialog,
                        onRemoveCategory: _removeCategoryDraft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsListSection(
                    key: const ValueKey('settings-section-tagging'),
                    title: '标签区设置',
                    highlighted: _taggingDirty(draft, saved),
                    children: [
                      SettingsTaggingContent(
                        controller: controller,
                        draft: draft,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SettingsListSection(
                    key: const ValueKey('settings-section-common'),
                    title: '通用设置',
                    highlighted: _commonDirty(draft, saved),
                    children: [
                      SettingsCommonContent(
                        controller: controller,
                        draft: draft,
                        onReloadChats: _loadChats,
                      ),
                    ],
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
      builder: (context) {
        final colors = AppTokens.colorsOf(context);
        return AlertDialog(
          title: const Text('删除分类'),
          content: const Text('这会从当前草稿中移除该分类，保存后才会真正生效。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
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
      builder: (context) {
        final colors = AppTokens.colorsOf(context);
        return AlertDialog(
          title: const Text('放弃更改'),
          content: const Text('离开或放弃后，当前未保存的修改都会丢失。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.danger,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('放弃'),
            ),
          ],
        );
      },
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

  bool _forwardingDirty(AppSettings current, AppSettings original) {
    return current.sourceChatId != original.sourceChatId ||
        current.fetchDirection != original.fetchDirection ||
        current.forwardAsCopy != original.forwardAsCopy ||
        current.batchSize != original.batchSize ||
        current.throttleMs != original.throttleMs ||
        current.previewPrefetchCount != original.previewPrefetchCount ||
        !_sameCategories(current.categories, original.categories);
  }

  bool _taggingDirty(AppSettings current, AppSettings original) {
    return current.tagSourceChatId != original.tagSourceChatId ||
        !_sameTagGroups(current.tagGroups, original.tagGroups);
  }

  bool _commonDirty(AppSettings current, AppSettings original) {
    return current.themeMode != original.themeMode ||
        current.proxy != original.proxy ||
        current.shortcutBindings != original.shortcutBindings;
  }

  bool _sameTagGroups(List<Object> left, List<Object> right) {
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
}
