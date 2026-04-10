import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_common_editors.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/features/settings/presentation/tag_group_editor.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/widgets/shortcut_bindings_editor.dart';

class SettingsForwardingContent extends StatelessWidget {
  const SettingsForwardingContent({
    super.key,
    required this.controller,
    required this.draft,
    required this.saved,
    required this.onAddCategory,
    required this.onRemoveCategory,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;
  final AppSettings saved;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(String key) onRemoveCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsWorkflowContent(controller: controller, draft: draft),
        const SizedBox(height: 12),
        SettingsCategoryContent(
          categories: draft.categories,
          savedCategories: saved.categories,
          chats: controller.chats.toList(growable: false),
          onAdd: onAddCategory,
          onChanged: (key, chat) =>
              controller.updateCategoryDraft(key: key, chat: chat),
          onRemove: onRemoveCategory,
        ),
      ],
    );
  }
}

class SettingsTaggingContent extends StatelessWidget {
  const SettingsTaggingContent({
    super.key,
    required this.controller,
    required this.draft,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SourceChatDraftEditor(
          label: '标签来源会话',
          sourceChatId: draft.tagSourceChatId,
          chats: controller.chats.toList(growable: false),
          onChanged: controller.updateTagSourceChatDraft,
        ),
        const SizedBox(height: 12),
        TagGroupEditor(
          group: _defaultGroup(draft.tagGroups),
          onAdd: controller.addDefaultTagDraft,
          onRemove: controller.removeDefaultTagDraft,
        ),
      ],
    );
  }

  TagGroupConfig _defaultGroup(List<TagGroupConfig> groups) {
    for (final group in groups) {
      if (group.key == TagGroupConfig.defaultGroupKey) {
        return group;
      }
    }
    return TagGroupConfig.emptyDefault;
  }
}

class SettingsCommonContent extends StatelessWidget {
  const SettingsCommonContent({
    super.key,
    required this.controller,
    required this.draft,
    required this.onReloadChats,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;
  final Future<void> Function() onReloadChats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsConnectionContent(controller: controller, draft: draft),
        const SizedBox(height: 12),
        SettingsToolsContent(
          controller: controller,
          draft: draft,
          onReloadChats: onReloadChats,
        ),
      ],
    );
  }
}

class SettingsWorkflowContent extends StatelessWidget {
  const SettingsWorkflowContent({
    super.key,
    required this.controller,
    required this.draft,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SourceChatDraftEditor(
          label: '转发来源会话',
          sourceChatId: draft.sourceChatId,
          chats: controller.chats.toList(growable: false),
          onChanged: controller.updateSourceChatDraft,
        ),
        const SizedBox(height: 12),
        FetchDirectionDraftEditor(
          value: draft.fetchDirection,
          onChanged: controller.updateFetchDirectionDraft,
        ),
        const SizedBox(height: 12),
        ForwardModeDraftEditor(
          value: draft.forwardAsCopy,
          onChanged: controller.updateForwardAsCopyDraft,
        ),
        const SizedBox(height: 12),
        BatchOptionsDraftEditor(
          batchSize: draft.batchSize,
          throttleMs: draft.throttleMs,
          onChanged: ({required batchSize, required throttleMs}) =>
              controller.updateBatchOptionsDraft(
                batchSize: batchSize,
                throttleMs: throttleMs,
              ),
        ),
        const SizedBox(height: 12),
        PreviewPrefetchDraftEditor(
          value: draft.previewPrefetchCount,
          onChanged: controller.updatePreviewPrefetchCountDraft,
        ),
      ],
    );
  }
}

class SettingsConnectionContent extends StatelessWidget {
  const SettingsConnectionContent({
    super.key,
    required this.controller,
    required this.draft,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;

  @override
  Widget build(BuildContext context) {
    return ProxySettingsDraftEditor(
      value: draft.proxy,
      onChanged:
          ({
            required server,
            required port,
            required username,
            required password,
          }) => controller.updateProxyDraft(
            server: server,
            port: port,
            username: username,
            password: password,
          ),
    );
  }
}

class SettingsToolsContent extends StatelessWidget {
  const SettingsToolsContent({
    super.key,
    required this.controller,
    required this.draft,
    required this.onReloadChats,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;
  final Future<void> Function() onReloadChats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsChatListRow(
          loading: controller.chatsLoading.value,
          chatsError: controller.chatsError.value,
          chatCount: controller.chats.length,
          onReload: onReloadChats,
        ),
        const SizedBox(height: 12),
        ShortcutBindingsEditor(
          bindings: draft.shortcutBindings,
          onChanged: (action, trigger, ctrl) => controller.updateShortcutDraft(
            action: action,
            trigger: trigger,
            ctrl: ctrl,
          ),
          onResetDefaults: controller.resetShortcutDefaultsDraft,
        ),
      ],
    );
  }
}
