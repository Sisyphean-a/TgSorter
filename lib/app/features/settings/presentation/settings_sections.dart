import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_common_editors.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_page_parts.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/widgets/settings_section_card.dart';
import 'package:tgsorter/app/widgets/shortcut_bindings_editor.dart';

class SettingsWorkflowSection extends StatelessWidget {
  const SettingsWorkflowSection({
    super.key,
    required this.controller,
    required this.draft,
    required this.saved,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;
  final AppSettings saved;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: '基础流程',
      subtitle: '管理消息来源、拉取顺序和批处理节奏。',
      highlighted: _workflowDirty(draft, saved),
      child: Column(
        children: [
          SourceChatDraftEditor(
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
            onChanged: ({
              required batchSize,
              required throttleMs,
            }) => controller.updateBatchOptionsDraft(
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
      ),
    );
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

class SettingsConnectionSection extends StatelessWidget {
  const SettingsConnectionSection({
    super.key,
    required this.controller,
    required this.draft,
    required this.saved,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;
  final AppSettings saved;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: '连接设置',
      subtitle: '代理配置会在保存后统一生效，并在必要时重连 TDLib。',
      highlighted: draft.proxy != saved.proxy,
      child: ProxySettingsDraftEditor(
        value: draft.proxy,
        onChanged: ({
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
      ),
    );
  }
}

class SettingsToolsSection extends StatelessWidget {
  const SettingsToolsSection({
    super.key,
    required this.controller,
    required this.draft,
    required this.saved,
    required this.recentLogs,
    required this.onReloadChats,
  });

  final SettingsCoordinator controller;
  final AppSettings draft;
  final AppSettings saved;
  final List<ClassifyOperationLog> recentLogs;
  final Future<void> Function() onReloadChats;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: '操作与工具',
      subtitle: '这里放即时操作和桌面端辅助配置，不参与分类规则本身。',
      highlighted: draft.shortcutBindings != saved.shortcutBindings,
      child: Column(
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
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('最近操作', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          SettingsRecentLogsPanel(logs: recentLogs),
        ],
      ),
    );
  }
}
