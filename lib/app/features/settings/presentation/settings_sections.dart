import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/skipped_message_summary.dart';
import 'package:tgsorter/app/features/settings/domain/download_settings.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_common_editors.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/features/settings/presentation/tag_group_editor.dart';
import 'package:tgsorter/app/features/settings/presentation/theme_mode_draft_editor.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';
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
    required this.onUpdateMediaLoadOptions,
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
  final void Function({
    required int backgroundConcurrency,
    required int retryLimit,
    required int retryDelayMs,
  })
  onUpdateMediaLoadOptions;
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
          onUpdateMediaLoadOptions: onUpdateMediaLoadOptions,
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

class SettingsDownloadContent extends StatelessWidget {
  const SettingsDownloadContent({
    super.key,
    required this.draft,
    required this.onWorkbenchEnabledChanged,
    required this.onSkipExistingFilesChanged,
    required this.onSyncDeletedFilesChanged,
    required this.onConflictStrategyChanged,
    required this.onMediaFilterChanged,
    required this.onDirectoryModeChanged,
  });

  final AppSettings draft;
  final ValueChanged<bool> onWorkbenchEnabledChanged;
  final ValueChanged<bool> onSkipExistingFilesChanged;
  final ValueChanged<bool> onSyncDeletedFilesChanged;
  final ValueChanged<DownloadConflictStrategy> onConflictStrategyChanged;
  final ValueChanged<DownloadMediaFilter> onMediaFilterChanged;
  final ValueChanged<DownloadDirectoryMode> onDirectoryModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '下载工作台'),
        DownloadWorkbenchEnabledEditor(
          value: draft.downloadWorkbenchEnabled,
          onChanged: onWorkbenchEnabledChanged,
        ),
        const SizedBox(height: 12),
        DownloadSkipExistingFilesEditor(
          value: draft.downloadSkipExistingFiles,
          onChanged: onSkipExistingFilesChanged,
        ),
        const SizedBox(height: 12),
        DownloadSyncDeletedFilesEditor(
          value: draft.downloadSyncDeletedFiles,
          onChanged: onSyncDeletedFilesChanged,
        ),
        const SizedBox(height: 12),
        DownloadConflictStrategyEditor(
          value: draft.downloadConflictStrategy,
          onChanged: onConflictStrategyChanged,
        ),
        const SizedBox(height: 12),
        DownloadDirectoryModeEditor(
          value: draft.downloadDirectoryMode,
          onChanged: onDirectoryModeChanged,
        ),
        const SizedBox(height: 12),
        DownloadMediaFilterEditor(
          value: draft.downloadMediaFilter,
          onChanged: onMediaFilterChanged,
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
    required this.onUpdateMediaLoadOptions,
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
  final void Function({
    required int backgroundConcurrency,
    required int retryLimit,
    required int retryDelayMs,
  })
  onUpdateMediaLoadOptions;

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
        const SizedBox(height: 12),
        MediaLoadOptionsDraftEditor(
          backgroundConcurrency: draft.mediaBackgroundDownloadConcurrency,
          retryLimit: draft.mediaRetryLimit,
          retryDelayMs: draft.mediaRetryDelayMs,
          onChanged: onUpdateMediaLoadOptions,
          onValidationChanged: onValidationChanged,
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

class SettingsSkippedMessagesContent extends StatelessWidget {
  const SettingsSkippedMessagesContent({
    super.key,
    required this.chats,
    required this.summary,
    required this.onRestoreAll,
    required this.onRestoreWorkflow,
    required this.onRestoreSource,
  });

  final List<SelectableChat> chats;
  final SkippedMessageSummary summary;
  final Future<int> Function() onRestoreAll;
  final Future<int> Function(SkippedMessageWorkflow workflow) onRestoreWorkflow;
  final Future<int> Function(SkippedMessageWorkflow workflow, int sourceChatId)
  onRestoreSource;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SettingsSectionHeader(title: '恢复已略过数据'),
        Text('恢复后，对应来源中的消息会重新回到转发或标签工作流。'),
        const SizedBox(height: 12),
        const SettingsSectionHeader(title: '全部恢复'),
        _SkippedRestoreActionRow(
          title: '全部略过记录',
          subtitle: '当前共有 ${summary.totalCount} 条略过记录',
          buttonLabel: '恢复全部',
          enabled: summary.totalCount > 0,
          onPressed: onRestoreAll,
        ),
        const SizedBox(height: 12),
        const SettingsSectionHeader(title: '按工作流恢复'),
        _SkippedRestoreActionRow(
          title: '转发工作流',
          subtitle: '当前有 ${summary.forwardingCount} 条略过记录',
          buttonLabel: '恢复转发',
          enabled: summary.forwardingCount > 0,
          onPressed: () => onRestoreWorkflow(SkippedMessageWorkflow.forwarding),
        ),
        const SizedBox(height: 8),
        _SkippedRestoreActionRow(
          title: '标签工作流',
          subtitle: '当前有 ${summary.taggingCount} 条略过记录',
          buttonLabel: '恢复标签',
          enabled: summary.taggingCount > 0,
          onPressed: () => onRestoreWorkflow(SkippedMessageWorkflow.tagging),
        ),
        const SizedBox(height: 12),
        const SettingsSectionHeader(title: '按来源恢复'),
        if (summary.sources.isEmpty) const Text('当前没有可按来源恢复的略过记录。'),
        for (final item in summary.sources) ...[
          _SkippedRestoreActionRow(
            title: _sourceTitle(item.sourceChatId),
            subtitle:
                '${_workflowLabel(item.workflow)} · 当前有 ${item.count} 条略过记录',
            buttonLabel: '恢复',
            enabled: item.count > 0,
            onPressed: () => onRestoreSource(item.workflow, item.sourceChatId),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  String _sourceTitle(int sourceChatId) {
    for (final chat in chats) {
      if (chat.id == sourceChatId) {
        return chat.title;
      }
    }
    return '来源 $sourceChatId';
  }

  String _workflowLabel(SkippedMessageWorkflow workflow) {
    switch (workflow) {
      case SkippedMessageWorkflow.forwarding:
        return '转发';
      case SkippedMessageWorkflow.tagging:
        return '标签';
    }
  }
}

class _SkippedRestoreActionRow extends StatelessWidget {
  const _SkippedRestoreActionRow({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool enabled;
  final Future<int> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonal(
          onPressed: enabled ? () => onPressed() : null,
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}
