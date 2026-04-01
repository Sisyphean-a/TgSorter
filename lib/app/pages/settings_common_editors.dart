import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

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

class ProxySettingsEditor extends StatefulWidget {
  const ProxySettingsEditor({
    super.key,
    required this.value,
    required this.onSave,
  });

  final ProxySettings value;
  final Future<void> Function({
    required String server,
    required String port,
    required String username,
    required String password,
  }) onSave;

  @override
  State<ProxySettingsEditor> createState() => _ProxySettingsEditorState();
}

class _ProxySettingsEditorState extends State<ProxySettingsEditor> {
  late final TextEditingController _serverCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: widget.value.server);
    _portCtrl = TextEditingController(text: widget.value.port?.toString() ?? '');
    _usernameCtrl = TextEditingController(text: widget.value.username);
    _passwordCtrl = TextEditingController(text: widget.value.password);
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('TDLib 代理', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _serverCtrl,
              decoration: const InputDecoration(labelText: '代理服务器'),
            ),
            TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '代理端口'),
            ),
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: '代理用户名（可选）'),
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: '代理密码（可选）'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () async {
                  await widget.onSave(
                    server: _serverCtrl.text,
                    port: _portCtrl.text,
                    username: _usernameCtrl.text,
                    password: _passwordCtrl.text,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('代理设置已保存并重新连接')),
                  );
                },
                child: const Text('保存代理'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
