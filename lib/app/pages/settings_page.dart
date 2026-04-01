import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/pages/settings_common_editors.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/widgets/shortcut_bindings_editor.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsController controller = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      await controller.loadChats();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载会话失败：$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类设置')),
      body: Obx(() {
        final config = controller.settings.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ChatListCard(
              loading: controller.chatsLoading.value,
              chatsError: controller.chatsError.value,
              onReload: _loadChats,
            ),
            const SizedBox(height: 8),
            ProxySettingsEditor(
              value: config.proxy,
              onSave: ({
                required server,
                required port,
                required username,
                required password,
              }) => controller.saveProxySettings(
                server: server,
                port: port,
                username: username,
                password: password,
                restart: true,
              ),
            ),
            const SizedBox(height: 8),
            _SourceChatEditor(
              sourceChatId: config.sourceChatId,
              onSave: controller.saveSourceChat,
            ),
            const SizedBox(height: 8),
            FetchDirectionEditor(
              value: config.fetchDirection,
              onChanged: controller.saveFetchDirection,
            ),
            const SizedBox(height: 8),
            BatchOptionsEditor(
              batchSize: config.batchSize,
              throttleMs: config.throttleMs,
              onSave: controller.saveBatchOptions,
            ),
            const SizedBox(height: 8),
            ShortcutBindingsEditor(
              controller: controller,
              bindings: config.shortcutBindings,
            ),
            const SizedBox(height: 8),
            _CategorySection(categories: config.categories),
          ],
        );
      }),
    );
  }
}

class _ChatListCard extends StatelessWidget {
  const _ChatListCard({
    required this.loading,
    required this.chatsError,
    required this.onReload,
  });

  final bool loading;
  final String? chatsError;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                chatsError == null
                    ? '可选会话：仅群组与频道'
                    : '会话列表加载失败：$chatsError',
              ),
            ),
            FilledButton.tonal(
              onPressed: loading ? null : onReload,
              child: Text(loading ? '加载中...' : '刷新会话'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceChatEditor extends StatelessWidget {
  const _SourceChatEditor({required this.sourceChatId, required this.onSave});

  final int? sourceChatId;
  final Future<void> Function(int?) onSave;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final chats = controller.chats.toList(growable: true);
    if (sourceChatId != null && !chats.any((item) => item.id == sourceChatId)) {
      chats.add(SelectableChat(id: sourceChatId!, title: '未知会话'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('来源会话', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              initialValue: sourceChatId,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('收藏夹（Saved Messages）'),
                ),
                ...chats.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text(item.title),
                  ),
                ),
              ],
              onChanged: (next) async {
                await onSave(next);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('来源会话已保存')));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.categories});

  final List<CategoryConfig> categories;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('分类', style: TextStyle(fontSize: 16)),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.chats.isEmpty
                      ? null
                      : () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => const _AddCategoryDialog(),
                          );
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('新增分类'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (categories.isEmpty) const Text('当前没有分类'),
            for (final item in categories)
              _CategoryEditor(
                key: ValueKey(item.key),
                category: item,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({super.key, required this.category});

  final CategoryConfig category;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  final SettingsController _controller = Get.find<SettingsController>();
  late int _selectedChatId;

  @override
  void initState() {
    super.initState();
    _selectedChatId = widget.category.targetChatId;
  }

  @override
  Widget build(BuildContext context) {
    final chats = _controller.chats.toList(growable: true);
    if (!chats.any((item) => item.id == _selectedChatId)) {
      chats.add(SelectableChat(id: _selectedChatId, title: '未知会话'));
    }
    final current = chats.firstWhere((item) => item.id == _selectedChatId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(current.title, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedChatId,
              decoration: const InputDecoration(
                labelText: '目标会话',
                border: OutlineInputBorder(),
              ),
              items: chats
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
                setState(() {
                  _selectedChatId = next;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await _controller.removeCategory(widget.category.key);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    final selected = chats.firstWhere(
                      (item) => item.id == _selectedChatId,
                    );
                    try {
                      await _controller.updateCategoryTarget(
                        key: widget.category.key,
                        chat: selected,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已保存')));
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  int? _selectedChatId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SettingsController>();
    final chats = controller.chats.toList(growable: false);
    return AlertDialog(
      title: const Text('新增分类'),
      content: DropdownButtonFormField<int>(
        initialValue: _selectedChatId,
        decoration: const InputDecoration(
          labelText: '目标会话',
          border: OutlineInputBorder(),
        ),
        items: chats
            .map(
              (item) => DropdownMenuItem<int>(
                value: item.id,
                child: Text(item.title),
              ),
            )
            .toList(growable: false),
        onChanged: (next) {
          setState(() {
            _selectedChatId = next;
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedChatId == null
              ? null
              : () async {
                  final selected = chats.firstWhere(
                    (item) => item.id == _selectedChatId,
                  );
                  try {
                    await controller.addCategory(selected);
                    if (!context.mounted) {
                      return;
                    }
                    Navigator.of(context).pop();
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
