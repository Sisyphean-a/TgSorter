import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_dialogs.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
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
    if (categories.isEmpty) {
      return SettingsSectionBlock(
        children: [
          SettingsValueTile(
            title: '新增分类',
            subtitle: '当前没有分类，点击后从可选会话中添加一个目标',
            onTap: chats.isEmpty ? null : onAdd,
            trailing: Icon(Icons.add_circle_outline, color: colors.settingsValue),
          ),
        ],
      );
    }
    return SettingsSectionBlock(
      children: [
        SettingsValueTile(
          title: '新增分类',
          subtitle: chats.isEmpty ? '当前没有可用目标会话' : '从当前会话列表中添加新的分类目标',
          onTap: chats.isEmpty ? null : onAdd,
          trailing: Icon(Icons.add_circle_outline, color: colors.settingsValue),
        ),
        for (final item in categories)
          _CategoryRow(
            category: item,
            statusLabel: _statusLabel(item, savedCategories),
            chats: chats,
            onChanged: onChanged,
            onRemove: onRemove,
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
        ? '仅群组与频道，当前已加载 $chatCount 个。'
        : '会话列表加载失败：$chatsError';
    return SettingsSectionBlock(
      children: [
        SettingsValueTile(
          title: '刷新会话',
          subtitle: description,
          value: loading ? '加载中...' : '刷新',
          onTap: loading ? null : onReload,
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
    return SettingsValueTile(
      title: category.key,
      subtitle: statusLabel,
      value: category.targetChatTitle,
      onTap: () async {
        final selected = await showSettingsChoiceSheet<int>(
          context,
          title: '选择 ${category.key} 目标会话',
          selectedValue: category.targetChatId,
          choices: options
              .map(
                (item) => SettingsChoice<int>(
                  value: item.id,
                  label: item.title,
                ),
              )
              .toList(growable: false),
        );
        if (selected == null) {
          return;
        }
        final chat = options.firstWhere((item) => item.id == selected);
        onChanged(category.key, chat);
      },
      trailing: IconButton(
        key: ValueKey('delete-category-${category.key}'),
        onPressed: () => onRemove(category.key),
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: '删除分类',
        visualDensity: VisualDensity.compact,
        color: colors.danger,
      ),
    );
  }
}
