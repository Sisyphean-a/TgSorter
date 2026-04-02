import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/pages/pipeline_log_formatter.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/widgets/settings_section_card.dart';

class SettingsCategorySection extends StatelessWidget {
  const SettingsCategorySection({
    super.key,
    required this.categories,
    required this.savedCategories,
    required this.chats,
    required this.onAdd,
    required this.onChanged,
    required this.onRemove,
  });

  final List<CategoryConfig> categories;
  final List<CategoryConfig> savedCategories;
  final List<SelectableChat> chats;
  final Future<void> Function() onAdd;
  final Future<void> Function(String key) onRemove;
  final void Function(String key, SelectableChat chat) onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: '分类管理',
      subtitle: '新增、改动和删除都只会进入草稿，统一随页面保存。',
      highlighted: !_sameCategories(categories, savedCategories),
      trailing: FilledButton.tonalIcon(
        onPressed: chats.isEmpty ? null : onAdd,
        icon: const Icon(Icons.add),
        label: const Text('新增分类'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('当前共 ${categories.length} 个分类'),
          const SizedBox(height: 12),
          if (categories.isEmpty) const Text('当前没有分类'),
          for (final item in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryRow(
                category: item,
                statusLabel: _statusLabel(item, savedCategories),
                chats: chats,
                onChanged: onChanged,
                onRemove: onRemove,
              ),
            ),
        ],
      ),
    );
  }

  String? _statusLabel(
    CategoryConfig category,
    List<CategoryConfig> savedCategories,
  ) {
    final original = _findSaved(savedCategories, category.key);
    if (original == null) {
      return '新建';
    }
    if (original == category) {
      return null;
    }
    return '已修改';
  }

  CategoryConfig? _findSaved(List<CategoryConfig> categories, String key) {
    for (final item in categories) {
      if (item.key == key) {
        return item;
      }
    }
    return null;
  }

  bool _sameCategories(
    List<CategoryConfig> left,
    List<CategoryConfig> right,
  ) {
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

class SettingsPageActions extends StatelessWidget {
  const SettingsPageActions({
    super.key,
    required this.isDirty,
    required this.onDiscard,
    required this.onSave,
  });

  final bool isDirty;
  final Future<void> Function() onDiscard;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isDirty ? onDiscard : null,
                child: const Text('放弃更改'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: isDirty ? onSave : null,
                child: const Text('保存更改'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsUnsavedChangesBanner extends StatelessWidget {
  const SettingsUnsavedChangesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text('当前有未保存更改，点击底部“保存更改”后才会正式生效。'),
      ),
    );
  }
}

class SettingsChatListRow extends StatelessWidget {
  const SettingsChatListRow({
    super.key,
    required this.loading,
    required this.chatsError,
    required this.chatCount,
    required this.onReload,
  });

  final bool loading;
  final String? chatsError;
  final int chatCount;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final description = chatsError == null
        ? '可选会话：仅群组与频道，当前已加载 $chatCount 个。'
        : '会话列表加载失败：$chatsError';
    return Row(
      children: [
        Expanded(child: Text(description)),
        FilledButton.tonal(
          onPressed: loading ? null : onReload,
          child: Text(loading ? '加载中...' : '刷新会话'),
        ),
      ],
    );
  }
}

class SettingsRecentLogsPanel extends StatelessWidget {
  const SettingsRecentLogsPanel({super.key, required this.logs});

  final List<ClassifyOperationLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Text('最近还没有操作记录。');
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                formatPipelineLog(logs[index]),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.statusLabel,
    required this.chats,
    required this.onChanged,
    required this.onRemove,
  });

  final CategoryConfig category;
  final String? statusLabel;
  final List<SelectableChat> chats;
  final Future<void> Function(String key) onRemove;
  final void Function(String key, SelectableChat chat) onChanged;

  @override
  Widget build(BuildContext context) {
    final options = chats.toList(growable: true);
    if (!options.any((item) => item.id == category.targetChatId)) {
      options.add(
        SelectableChat(id: category.targetChatId, title: category.targetChatTitle),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category.targetChatTitle,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                if (statusLabel != null)
                  Chip(
                    label: Text(statusLabel!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('${category.key}_${category.targetChatId}'),
              initialValue: category.targetChatId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '目标会话',
                border: OutlineInputBorder(),
              ),
              items: options
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(item.title),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next == null) {
                  return;
                }
                final selected = options.firstWhere((item) => item.id == next);
                onChanged(category.key, selected);
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onRemove(category.key),
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
