import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/widgets/shortcut_bindings_editor.dart';
import 'package:tgsorter/app/pages/settings_common_editors.dart';

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
            for (final item in config.categories)
              _CategoryEditor(
                key: ValueKey(item.key),
                categoryKey: item.key,
                initialName: item.name,
                initialTargetChatId: item.targetChatId,
              ),
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
                    child: Text(_chatLabel(item)),
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

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    super.key,
    required this.categoryKey,
    required this.initialName,
    required this.initialTargetChatId,
  });

  final String categoryKey;
  final String initialName;
  final int? initialTargetChatId;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _nameCtrl;
  final SettingsController _controller = Get.find<SettingsController>();
  int? _selectedChatId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selectedChatId = widget.initialTargetChatId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = _controller.chats.toList(growable: true);
    if (_selectedChatId != null &&
        !chats.any((item) => item.id == _selectedChatId)) {
      chats.add(SelectableChat(id: _selectedChatId!, title: '未知会话'));
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '按钮名称'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _selectedChatId,
              decoration: const InputDecoration(
                labelText: '目标会话（群组/频道）',
                border: OutlineInputBorder(),
              ),
              items: chats
                  .map(
                    (item) => DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(_chatLabel(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                setState(() {
                  _selectedChatId = next;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedChatId = null;
                    });
                  },
                  child: const Text('清空目标'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    await _controller.saveCategory(
                      key: widget.categoryKey,
                      name: _nameCtrl.text,
                      targetChatId: _selectedChatId,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已保存')));
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

String _chatLabel(SelectableChat chat) {
  return '${chat.title} (${chat.id})';
}
