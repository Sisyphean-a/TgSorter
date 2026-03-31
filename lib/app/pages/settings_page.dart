import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';

class SettingsPage extends StatelessWidget {
  SettingsPage({super.key});

  final SettingsController controller = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分类设置')),
      body: Obx(() {
        final categories = controller.settings.value.categories;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已保存')),
                  );
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
