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
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.controller,
    required this.navigation,
    required this.draftSession,
    this.pipeline,
    super.key,
  });

  final SettingsCoordinator controller;
  final SettingsNavigationController navigation;
  final SettingsPageDraftSession draftSession;
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
      case SettingsRoute.forwarding:
        return SettingsDetailPage(
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
            onUpdateCategory: widget.draftSession.updateCategory,
          ),
        );
      case SettingsRoute.tagging:
        return SettingsDetailPage(
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
      case SettingsRoute.appearance:
        return SettingsDetailPage(
          child: SettingsAppearanceContent(
            draft: draft,
            onChanged: widget.draftSession.updateThemeMode,
          ),
        );
      case SettingsRoute.shortcuts:
        return SettingsDetailPage(
          child: SettingsShortcutsContent(
            draft: draft,
            onChanged: widget.draftSession.updateShortcut,
            onResetDefaults: widget.draftSession.resetShortcutDefaults,
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
    widget.navigation.goTo(route);
  }
}
