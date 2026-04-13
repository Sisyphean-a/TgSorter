import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsCategoryContent extends StatelessWidget {
  const SettingsCategoryContent({
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
    final colors = AppTokens.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: chats.isEmpty ? null : onAdd,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.add),
            label: const Text('新增分类'),
          ),
        ),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Text(
            '当前没有分类',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          ),
        for (final item in categories)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: _CategoryRow(
              category: item,
              statusLabel: _statusLabel(item, savedCategories),
              chats: chats,
              onChanged: onChanged,
              onRemove: onRemove,
            ),
          ),
      ],
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
    final colors = AppTokens.colorsOf(context);
    final options = chats.toList(growable: true);
    if (!options.any((item) => item.id == category.targetChatId)) {
      options.add(
        SelectableChat(
          id: category.targetChatId,
          title: category.targetChatTitle,
        ),
      );
    }
    return Material(
      color: colors.settingsSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    horizontal: 10,
                    vertical: 8,
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
              const SizedBox(width: 8),
              Text(
                statusLabel!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
            IconButton(
              key: ValueKey('delete-category-${category.key}'),
              onPressed: () => onRemove(category.key),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '删除分类',
              visualDensity: VisualDensity.compact,
              color: colors.danger,
            ),
          ],
        ),
      ),
    );
  }
}
