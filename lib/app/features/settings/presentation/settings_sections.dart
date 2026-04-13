import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_common_editors.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/features/settings/presentation/tag_group_editor.dart';
import 'package:tgsorter/app/features/settings/presentation/theme_mode_draft_editor.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/default_workbench.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/widgets/shortcut_bindings_editor.dart';

class SettingsForwardingContent extends StatelessWidget {
  const SettingsForwardingContent({
    super.key,
    required this.chats,
    required this.draft,
    required this.saved,
    required this.onAddCategory,
    required this.onRemoveCategory,
    required this.onUpdateSourceChat,
    required this.onUpdateFetchDirection,
    required this.onUpdateForwardAsCopy,
    required this.onUpdateBatchOptions,
    required this.onValidationChanged,
    required this.onUpdatePreviewPrefetchCount,
    required this.onUpdateCategory,
  });

  final List<SelectableChat> chats;
  final AppSettings draft;
  final AppSettings saved;
  final Future<void> Function() onAddCategory;
  final Future<void> Function(String key) onRemoveCategory;
  final ValueChanged<int?> onUpdateSourceChat;
  final ValueChanged<MessageFetchDirection> onUpdateFetchDirection;
  final ValueChanged<bool> onUpdateForwardAsCopy;
  final void Function({required int batchSize, required int throttleMs})
  onUpdateBatchOptions;
  final ValueChanged<bool> onValidationChanged;
  final ValueChanged<int> onUpdatePreviewPrefetchCount;
  final void Function({required String key, required SelectableChat chat})
  onUpdateCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '转发规则'),
        SettingsWorkflowContent(
          chats: chats,
          draft: draft,
          onUpdateSourceChat: onUpdateSourceChat,
          onUpdateFetchDirection: onUpdateFetchDirection,
          onUpdateForwardAsCopy: onUpdateForwardAsCopy,
          onUpdateBatchOptions: onUpdateBatchOptions,
          onValidationChanged: onValidationChanged,
          onUpdatePreviewPrefetchCount: onUpdatePreviewPrefetchCount,
        ),
        const SizedBox(height: 12),
        const SettingsSectionHeader(title: '分类目标'),
        SettingsCategoryContent(
          categories: draft.categories,
          savedCategories: saved.categories,
          chats: chats,
          onAdd: onAddCategory,
          onChanged: (key, chat) => onUpdateCategory(key: key, chat: chat),
          onRemove: onRemoveCategory,
        ),
      ],
    );
  }
}

class SettingsTaggingContent extends StatelessWidget {
  const SettingsTaggingContent({
    super.key,
    required this.chats,
    required this.draft,
    required this.onUpdateSourceChat,
    required this.onAddDefaultTag,
    required this.onRemoveDefaultTag,
  });

  final List<SelectableChat> chats;
  final AppSettings draft;
  final ValueChanged<int?> onUpdateSourceChat;
  final ValueChanged<String> onAddDefaultTag;
  final ValueChanged<String> onRemoveDefaultTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '标签来源'),
        SourceChatDraftEditor(
          label: '标签来源会话',
          sourceChatId: draft.tagSourceChatId,
          chats: chats,
          onChanged: onUpdateSourceChat,
        ),
        const SizedBox(height: 12),
        const SettingsSectionHeader(title: '默认标签组'),
        TagGroupEditor(
          group: _defaultGroup(draft.tagGroups),
          onAdd: onAddDefaultTag,
          onRemove: onRemoveDefaultTag,
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
    required this.draft,
    required this.onThemeModeChanged,
    required this.onDefaultWorkbenchChanged,
  });

  final AppSettings draft;
  final ValueChanged<AppThemeMode> onThemeModeChanged;
  final ValueChanged<AppDefaultWorkbench> onDefaultWorkbenchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '通用偏好'),
        DefaultWorkbenchDraftEditor(
          value: draft.defaultWorkbench,
          onChanged: onDefaultWorkbenchChanged,
        ),
        const SizedBox(height: 12),
        ThemeModeDraftEditor(
          value: draft.themeMode,
          onChanged: onThemeModeChanged,
        ),
      ],
    );
  }
}

class SettingsWorkflowContent extends StatelessWidget {
  const SettingsWorkflowContent({
    super.key,
    required this.chats,
    required this.draft,
    required this.onUpdateSourceChat,
    required this.onUpdateFetchDirection,
    required this.onUpdateForwardAsCopy,
    required this.onUpdateBatchOptions,
    required this.onValidationChanged,
    required this.onUpdatePreviewPrefetchCount,
  });

  final List<SelectableChat> chats;
  final AppSettings draft;
  final ValueChanged<int?> onUpdateSourceChat;
  final ValueChanged<MessageFetchDirection> onUpdateFetchDirection;
  final ValueChanged<bool> onUpdateForwardAsCopy;
  final void Function({required int batchSize, required int throttleMs})
  onUpdateBatchOptions;
  final ValueChanged<bool> onValidationChanged;
  final ValueChanged<int> onUpdatePreviewPrefetchCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SourceChatDraftEditor(
          label: '转发来源会话',
          sourceChatId: draft.sourceChatId,
          chats: chats,
          onChanged: onUpdateSourceChat,
        ),
        const SizedBox(height: 12),
        FetchDirectionDraftEditor(
          value: draft.fetchDirection,
          onChanged: onUpdateFetchDirection,
        ),
        const SizedBox(height: 12),
        ForwardModeDraftEditor(
          value: draft.forwardAsCopy,
          onChanged: onUpdateForwardAsCopy,
        ),
        const SizedBox(height: 12),
        BatchOptionsDraftEditor(
          batchSize: draft.batchSize,
          throttleMs: draft.throttleMs,
          onChanged: onUpdateBatchOptions,
          onValidationChanged: onValidationChanged,
        ),
        const SizedBox(height: 12),
        PreviewPrefetchDraftEditor(
          value: draft.previewPrefetchCount,
          onChanged: onUpdatePreviewPrefetchCount,
        ),
      ],
    );
  }
}

class SettingsConnectionContent extends StatelessWidget {
  const SettingsConnectionContent({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onValidationChanged,
  });

  final AppSettings draft;
  final void Function({
    required String server,
    required String port,
    required String username,
    required String password,
  })
  onChanged;
  final ValueChanged<bool> onValidationChanged;

  @override
  Widget build(BuildContext context) {
    return ProxySettingsDraftEditor(
      value: draft.proxy,
      onChanged: onChanged,
      onValidationChanged: onValidationChanged,
    );
  }
}

class SettingsShortcutsContent extends StatelessWidget {
  const SettingsShortcutsContent({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onResetDefaults,
  });

  final AppSettings draft;
  final void Function({
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  })
  onChanged;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '快捷键绑定'),
        ShortcutBindingsEditor(
          bindings: draft.shortcutBindings,
          onChanged: (action, trigger, ctrl) =>
              onChanged(action: action, trigger: trigger, ctrl: ctrl),
          onResetDefaults: onResetDefaults,
        ),
      ],
    );
  }
}

class SettingsAccountSessionContent extends StatelessWidget {
  const SettingsAccountSessionContent({
    super.key,
    required this.chatsLoading,
    required this.chatsError,
    required this.chatCount,
    required this.onReloadChats,
    required this.onLogout,
  });

  final bool chatsLoading;
  final String? chatsError;
  final int chatCount;
  final Future<void> Function() onReloadChats;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '账号与会话'),
        SettingsChatListRow(
          loading: chatsLoading,
          chatsError: chatsError,
          chatCount: chatCount,
          onReload: onReloadChats,
        ),
        const SizedBox(height: 12),
        const SettingsSectionHeader(title: '登录控制'),
        Text('退出后会返回登录页，并清空当前工作台缓存、待重试队列和恢复事务。应用设置会保留。'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('退出登录'),
          ),
        ),
      ],
    );
  }
}
