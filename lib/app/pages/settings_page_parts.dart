import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/pages/pipeline_log_formatter.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
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
      highlighted: !_sameCategories(categories, savedCategories),
      trailing: FilledButton.tonalIcon(
        onPressed: chats.isEmpty ? null : onAdd,
        icon: const Icon(Icons.add),
        label: const Text('新增分类'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categories.isEmpty) const Text('当前没有分类'),
          for (final item in categories)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
}

class SettingsUnsavedChangesBanner extends StatelessWidget {
  const SettingsUnsavedChangesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.brandAccentSoft,
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      child: const Padding(
        padding: EdgeInsets.all(AppTokens.spaceMd),
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
          color: AppTokens.surfaceBase,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(color: AppTokens.borderSubtle),
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
        SelectableChat(
          id: category.targetChatId,
          title: category.targetChatTitle,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.surfaceBase,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('${category.key}_${category.targetChatId}'),
                initialValue: category.targetChatId,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  hintText: '目标会话',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: options
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (next) {
                  if (next == null) {
                    return;
                  }
                  final selected = options.firstWhere(
                    (item) => item.id == next,
                  );
                  onChanged(category.key, selected);
                },
              ),
            ),
            if (statusLabel != null) ...[
              const SizedBox(width: 6),
              Chip(
                label: Text(statusLabel!),
                visualDensity: VisualDensity.compact,
              ),
            ],
            const SizedBox(width: 6),
            IconButton(
              key: ValueKey('delete-category-${category.key}'),
              onPressed: () => onRemove(category.key),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '删除分类',
              visualDensity: VisualDensity.compact,
              color: AppTokens.danger,
            ),
          ],
        ),
      ),
    );
  }
}
