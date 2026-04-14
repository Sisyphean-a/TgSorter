import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/application/settings_page_draft_session.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_category_dialog.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_detail_page.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_home_page.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_sections.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/features/settings/ports/pipeline_logs_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.controller,
    required this.navigation,
    required this.draftSession,
    this.pipeline,
    this.onLogoutSuccess,
    super.key,
  });

  final SettingsCoordinator controller;
  final SettingsNavigationController navigation;
  final SettingsPageDraftSession draftSession;
  final PipelineLogsPort? pipeline;
  final Future<void> Function()? onLogoutSuccess;

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
      final route = widget.navigation.currentRoute.value;
      final draft = widget.draftSession.draftSettings.value;
      final saved = controller.savedSettings.value;
      return PopScope<void>(
        canPop: route == SettingsRoute.home,
        onPopInvokedWithResult: _handlePopAttempt,
        child: _buildBody(route: route, draft: draft, saved: saved),
      );
    });
  }

  Widget _buildBody({
    required SettingsRoute route,
    required AppSettings draft,
    required AppSettings saved,
  }) {
    switch (route) {
      case SettingsRoute.home:
        return SettingsHomePage(onOpenRoute: _openRoute);
      case SettingsRoute.common:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsCommonContent(
            draft: draft,
            onThemeModeChanged: widget.draftSession.updateThemeMode,
            onDefaultWorkbenchChanged:
                widget.draftSession.updateDefaultWorkbench,
          ),
        );
      case SettingsRoute.downloads:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsDownloadContent(
            draft: draft,
            onWorkbenchEnabledChanged:
                widget.draftSession.updateDownloadWorkbenchEnabled,
            onSkipExistingFilesChanged:
                widget.draftSession.updateDownloadSkipExistingFiles,
            onSyncDeletedFilesChanged:
                widget.draftSession.updateDownloadSyncDeletedFiles,
            onConflictStrategyChanged:
                widget.draftSession.updateDownloadConflictStrategy,
            onMediaFilterChanged:
                widget.draftSession.updateDownloadMediaFilter,
            onDirectoryModeChanged:
                widget.draftSession.updateDownloadDirectoryMode,
          ),
        );
      case SettingsRoute.skippedMessages:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsSkippedMessagesContent(
            chats: controller.chats.toList(growable: false),
            summary: controller.skippedMessageSummary.value,
            onRestoreAll: () => _restoreSkippedMessages(),
            onRestoreWorkflow: (workflow) =>
                _restoreSkippedMessages(workflow: workflow),
            onRestoreSource: (workflow, sourceChatId) =>
                _restoreSkippedMessages(
                  workflow: workflow,
                  sourceChatId: sourceChatId,
                ),
          ),
        );
      case SettingsRoute.forwarding:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsForwardingContent(
            chats: controller.chats.toList(growable: false),
            draft: draft,
            saved: saved,
            onAddCategory: _showAddCategoryDialog,
            onRemoveCategory: _removeCategoryDraft,
            onUpdateSourceChat: widget.draftSession.updateSourceChat,
            onUpdateFetchDirection: widget.draftSession.updateFetchDirection,
            onUpdateForwardAsCopy: widget.draftSession.updateForwardAsCopy,
            onUpdateBatchOptions: widget.draftSession.updateBatchOptions,
            onValidationChanged: widget.draftSession.setHasValidationErrors,
            onUpdatePreviewPrefetchCount:
                widget.draftSession.updatePreviewPrefetchCount,
            onUpdateMediaLoadOptions:
                widget.draftSession.updateMediaLoadOptions,
            onUpdateCategory: widget.draftSession.updateCategory,
          ),
        );
      case SettingsRoute.tagging:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsTaggingContent(
            chats: controller.chats.toList(growable: false),
            draft: draft,
            onUpdateSourceChat: widget.draftSession.updateTagSourceChat,
            onAddDefaultTag: widget.draftSession.addDefaultTag,
            onRemoveDefaultTag: widget.draftSession.removeDefaultTag,
          ),
        );
      case SettingsRoute.connection:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SettingsSectionHeader(title: '代理设置'),
              SettingsConnectionContent(
                draft: draft,
                onChanged: widget.draftSession.updateProxy,
                onValidationChanged: widget.draftSession.setHasValidationErrors,
              ),
              const SizedBox(height: 12),
              const SettingsSectionHeader(title: '会话列表'),
              SettingsChatListRow(
                loading: controller.chatsLoading.value,
                chatsError: controller.chatsError.value,
                chatCount: controller.chats.length,
                onReload: _loadChats,
              ),
            ],
          ),
        );
      case SettingsRoute.shortcuts:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsShortcutsContent(
            draft: draft,
            onChanged: widget.draftSession.updateShortcut,
            onResetDefaults: widget.draftSession.resetShortcutDefaults,
          ),
        );
      case SettingsRoute.accountSession:
        return SettingsDetailPage(
          ignoring: controller.isSaving.value,
          child: SettingsAccountSessionContent(
            chatsLoading: controller.chatsLoading.value,
            chatsError: controller.chatsError.value,
            chatCount: controller.chats.length,
            onReloadChats: _loadChats,
            onLogout: _handleLogout,
          ),
        );
    }
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

  Future<void> _showAddCategoryDialog() async {
    final availableChats = _availableCategoryChats();
    await showDialog<void>(
      context: context,
      builder: (_) => AddCategoryDialog(
        chats: availableChats,
        onAdd: (chat) {
          try {
            widget.draftSession.addCategory(chat);
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
    widget.draftSession.removeCategory(key);
  }

  Future<void> _handlePopAttempt(bool didPop, void _) async {
    if (didPop || widget.navigation.currentRoute.value == SettingsRoute.home) {
      return;
    }
    if (controller.isSaving.value) {
      return;
    }
    if (!widget.draftSession.hasPendingChanges) {
      widget.draftSession.clear();
      widget.navigation.backToHome();
      return;
    }
    final confirmed = await _confirmDiscard();
    if (!confirmed) {
      return;
    }
    widget.draftSession.clear();
    widget.navigation.backToHome();
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
              child: const Text('放弃更改'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  List<SelectableChat> _availableCategoryChats() {
    final usedIds = widget.draftSession.draftSettings.value.categories
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

  void _openRoute(SettingsRoute route) {
    widget.draftSession.open(
      route: route,
      savedSettings: controller.savedSettings.value,
    );
    if (route == SettingsRoute.skippedMessages) {
      controller.refreshSkippedMessageSummary();
    }
    widget.navigation.goTo(route);
  }

  Future<int> _restoreSkippedMessages({
    SkippedMessageWorkflow? workflow,
    int? sourceChatId,
  }) async {
    try {
      final restored = await controller.restoreSkippedMessages(
        workflow: workflow,
        sourceChatId: sourceChatId,
      );
      if (!mounted) {
        return restored;
      }
      _showMessage(restored <= 0 ? '当前没有可恢复的略过记录' : '已恢复 $restored 条略过记录');
      return restored;
    } catch (error) {
      if (!mounted) {
        return 0;
      }
      _showMessage('恢复略过记录失败：$error');
      return 0;
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = AppTokens.colorsOf(context);
        return AlertDialog(
          title: const Text('确认退出登录'),
          content: const Text('退出后会返回登录页。当前工作台缓存、待重试队列和恢复事务会被清空，应用设置会保留。'),
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
              child: const Text('确认退出'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await controller.logout();
      await widget.onLogoutSuccess?.call();
      if (!mounted) {
        return;
      }
      widget.draftSession.clear();
      widget.navigation.backToHome();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('退出登录失败：$error');
    }
  }
}
