import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_settings.dart';

class BatchOptionsEditor extends StatefulWidget {
  const BatchOptionsEditor({
    super.key,
    required this.batchSize,
    required this.throttleMs,
    required this.onSave,
  });

  final int batchSize;
  final int throttleMs;
  final Future<void> Function({required int batchSize, required int throttleMs})
  onSave;

  @override
  State<BatchOptionsEditor> createState() => _BatchOptionsEditorState();
}

class _BatchOptionsEditorState extends State<BatchOptionsEditor> {
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

class FetchDirectionEditor extends StatelessWidget {
  const FetchDirectionEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

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
