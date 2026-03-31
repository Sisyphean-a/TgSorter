import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/widgets/shortcut_bindings_editor.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final SettingsController controller = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类设置')),
      body: Obx(() {
        final categories = controller.settings.value.categories;
        final fetchDirection = controller.settings.value.fetchDirection;
        final batchSize = controller.settings.value.batchSize;
        final throttleMs = controller.settings.value.throttleMs;
        final shortcuts = controller.settings.value.shortcutBindings;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _FetchDirectionEditor(
              value: fetchDirection,
              onChanged: controller.saveFetchDirection,
            ),
            const SizedBox(height: 8),
            _BatchOptionsEditor(
              batchSize: batchSize,
              throttleMs: throttleMs,
              onSave: controller.saveBatchOptions,
            ),
            const SizedBox(height: 8),
            ShortcutBindingsEditor(controller: controller, bindings: shortcuts),
            const SizedBox(height: 8),
            for (final item in categories)
              _CategoryEditor(
                key: ValueKey(item.key),
                categoryKey: item.key,
                initialName: item.name,
                initialChatId: item.targetChatId?.toString() ?? '',
              ),
          ],
        );
      }),
    );
  }
}

class _BatchOptionsEditor extends StatefulWidget {
  const _BatchOptionsEditor({
    required this.batchSize,
    required this.throttleMs,
    required this.onSave,
  });

  final int batchSize;
  final int throttleMs;
  final Future<void> Function({required int batchSize, required int throttleMs})
  onSave;

  @override
  State<_BatchOptionsEditor> createState() => _BatchOptionsEditorState();
}

class _BatchOptionsEditorState extends State<_BatchOptionsEditor> {
  late final TextEditingController _batchCtrl;
  late final TextEditingController _throttleCtrl;

  @override
  void initState() {
    super.initState();
    _batchCtrl = TextEditingController(text: widget.batchSize.toString());
    _throttleCtrl = TextEditingController(text: widget.throttleMs.toString());
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    _throttleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('批处理与节流', style: TextStyle(fontSize: 16)),
            ),
            TextField(
              controller: _batchCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '批处理条数 N'),
            ),
            TextField(
              controller: _throttleCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '节流毫秒'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  final batch = int.tryParse(_batchCtrl.text.trim()) ?? 1;
                  final throttle = int.tryParse(_throttleCtrl.text.trim()) ?? 0;
                  await widget.onSave(batchSize: batch, throttleMs: throttle);
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('批处理设置已保存')));
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FetchDirectionEditor extends StatelessWidget {
  const _FetchDirectionEditor({required this.value, required this.onChanged});

  final MessageFetchDirection value;
  final Future<void> Function(MessageFetchDirection) onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('消息拉取方向', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<MessageFetchDirection>(
              initialValue: value,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                  value: MessageFetchDirection.latestFirst,
                  child: Text('最新优先'),
                ),
                DropdownMenuItem(
                  value: MessageFetchDirection.oldestFirst,
                  child: Text('最旧优先'),
                ),
              ],
              onChanged: (next) async {
                if (next == null) {
                  return;
                }
                await onChanged(next);
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('拉取方向已保存')));
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
    required this.initialChatId,
  });

  final String categoryKey;
  final String initialName;
  final String initialChatId;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _chatCtrl;
  final SettingsController _controller = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _chatCtrl = TextEditingController(text: widget.initialChatId);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            TextField(
              controller: _chatCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '目标 Chat ID'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  await _controller.saveCategory(
                    key: widget.categoryKey,
                    name: _nameCtrl.text,
                    chatIdRaw: _chatCtrl.text,
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
            ),
          ],
        ),
      ),
    );
  }
}
