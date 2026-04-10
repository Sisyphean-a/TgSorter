import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SourceChatDraftEditor extends StatelessWidget {
  const SourceChatDraftEditor({
    super.key,
    required this.sourceChatId,
    required this.chats,
    required this.onChanged,
  });

  final int? sourceChatId;
  final List<SelectableChat> chats;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = chats.toList(growable: true);
    if (sourceChatId != null &&
        !options.any((item) => item.id == sourceChatId)) {
      options.add(SelectableChat(id: sourceChatId!, title: '未知会话'));
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '来源会话',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTokens.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<int?>(
          key: ValueKey(sourceChatId),
          initialValue: sourceChatId,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('收藏夹（Saved Messages）'),
            ),
            ...options.map(
              (item) => DropdownMenuItem<int?>(
                value: item.id,
                child: Text(item.title),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class FetchDirectionDraftEditor extends StatelessWidget {
  const FetchDirectionDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final MessageFetchDirection value;
  final ValueChanged<MessageFetchDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<MessageFetchDirection>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '消息拉取方向'),
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
      onChanged: (next) {
        if (next == null) {
          return;
        }
        onChanged(next);
      },
    );
  }
}

class ForwardModeDraftEditor extends StatelessWidget {
  const ForwardModeDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      value: value,
      title: const Text('无引用转发'),
      onChanged: onChanged,
    );
  }
}

class BatchOptionsDraftEditor extends StatefulWidget {
  const BatchOptionsDraftEditor({
    super.key,
    required this.batchSize,
    required this.throttleMs,
    required this.onChanged,
  });

  final int batchSize;
  final int throttleMs;
  final void Function({required int batchSize, required int throttleMs})
  onChanged;

  @override
  State<BatchOptionsDraftEditor> createState() =>
      _BatchOptionsDraftEditorState();
}

class PreviewPrefetchDraftEditor extends StatelessWidget {
  const PreviewPrefetchDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '预加载后续预览'),
      items: const [
        DropdownMenuItem(value: 0, child: Text('关闭')),
        DropdownMenuItem(value: 1, child: Text('1 条')),
        DropdownMenuItem(value: 3, child: Text('3 条')),
        DropdownMenuItem(value: 5, child: Text('5 条')),
      ],
      onChanged: (next) {
        if (next == null) {
          return;
        }
        onChanged(next);
      },
    );
  }
}

class _BatchOptionsDraftEditorState extends State<BatchOptionsDraftEditor> {
  late final TextEditingController _batchCtrl;
  late final TextEditingController _throttleCtrl;

  @override
  void initState() {
    super.initState();
    _batchCtrl = TextEditingController(text: widget.batchSize.toString());
    _throttleCtrl = TextEditingController(text: widget.throttleMs.toString());
  }

  @override
  void didUpdateWidget(covariant BatchOptionsDraftEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batchSize != widget.batchSize) {
      _batchCtrl.text = widget.batchSize.toString();
    }
    if (oldWidget.throttleMs != widget.throttleMs) {
      _throttleCtrl.text = widget.throttleMs.toString();
    }
  }

  @override
  void dispose() {
    _batchCtrl.dispose();
    _throttleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _batchCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '批处理条数 N'),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _throttleCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '节流毫秒'),
          onChanged: (_) => _notifyChange(),
        ),
      ],
    );
  }

  void _notifyChange() {
    final batch = int.tryParse(_batchCtrl.text.trim()) ?? 1;
    final throttle = int.tryParse(_throttleCtrl.text.trim()) ?? 0;
    widget.onChanged(batchSize: batch, throttleMs: throttle);
  }
}

class ProxySettingsDraftEditor extends StatefulWidget {
  const ProxySettingsDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ProxySettings value;
  final void Function({
    required String server,
    required String port,
    required String username,
    required String password,
  })
  onChanged;

  @override
  State<ProxySettingsDraftEditor> createState() =>
      _ProxySettingsDraftEditorState();
}

class _ProxySettingsDraftEditorState extends State<ProxySettingsDraftEditor> {
  late final TextEditingController _serverCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: widget.value.server);
    _portCtrl = TextEditingController(
      text: widget.value.port?.toString() ?? '',
    );
    _usernameCtrl = TextEditingController(text: widget.value.username);
    _passwordCtrl = TextEditingController(text: widget.value.password);
  }

  @override
  void didUpdateWidget(covariant ProxySettingsDraftEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) {
      return;
    }
    _serverCtrl.text = widget.value.server;
    _portCtrl.text = widget.value.port?.toString() ?? '';
    _usernameCtrl.text = widget.value.username;
    _passwordCtrl.text = widget.value.password;
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
    return Column(
      children: [
        TextField(
          controller: _serverCtrl,
          decoration: const InputDecoration(labelText: '代理服务器'),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _portCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '代理端口'),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameCtrl,
          decoration: const InputDecoration(labelText: '代理用户名（可选）'),
          onChanged: (_) => _notifyChange(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          decoration: const InputDecoration(labelText: '代理密码（可选）'),
          obscureText: true,
          onChanged: (_) => _notifyChange(),
        ),
      ],
    );
  }

  void _notifyChange() {
    widget.onChanged(
      server: _serverCtrl.text,
      port: _portCtrl.text,
      username: _usernameCtrl.text,
      password: _passwordCtrl.text,
    );
  }
}
