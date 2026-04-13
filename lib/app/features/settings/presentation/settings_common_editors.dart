import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/settings_input_validator.dart';
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
    this.label = '来源会话',
  });

  final int? sourceChatId;
  final List<SelectableChat> chats;
  final ValueChanged<int?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final options = chats.toList(growable: true);
    if (sourceChatId != null &&
        !options.any((item) => item.id == sourceChatId)) {
      options.add(SelectableChat(id: sourceChatId!, title: '未知会话'));
    }
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.textMuted,
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

class DefaultWorkbenchDraftEditor extends StatelessWidget {
  const DefaultWorkbenchDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppDefaultWorkbench value;
  final ValueChanged<AppDefaultWorkbench> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AppDefaultWorkbench>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '首页默认工作台'),
      items: const [
        DropdownMenuItem(
          value: AppDefaultWorkbench.forwarding,
          child: Text('转发工作台'),
        ),
        DropdownMenuItem(
          value: AppDefaultWorkbench.tagging,
          child: Text('标签工作台'),
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
    this.onValidationChanged,
  });

  final int batchSize;
  final int throttleMs;
  final void Function({required int batchSize, required int throttleMs})
  onChanged;
  final ValueChanged<bool>? onValidationChanged;

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
  final _validator = SettingsInputValidator();
  late final TextEditingController _batchCtrl;
  late final TextEditingController _throttleCtrl;
  String? _batchError;
  String? _throttleError;

  @override
  void initState() {
    super.initState();
    _batchCtrl = TextEditingController(text: widget.batchSize.toString());
    _throttleCtrl = TextEditingController(text: widget.throttleMs.toString());
    _syncValidationState(notifyModel: false);
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
    _syncValidationState(notifyModel: false);
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
          decoration: InputDecoration(
            labelText: '批处理条数 N',
            errorText: _batchError,
          ),
          onChanged: (_) => _syncValidationState(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _throttleCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '节流毫秒',
            errorText: _throttleError,
          ),
          onChanged: (_) => _syncValidationState(),
        ),
      ],
    );
  }

  bool get _hasErrors => _batchError != null || _throttleError != null;

  void _syncValidationState({bool notifyModel = true}) {
    setState(() {
      _batchError = _validator.validateBatchSizeText(_batchCtrl.text);
      _throttleError = _validator.validateThrottleText(_throttleCtrl.text);
    });
    widget.onValidationChanged?.call(_hasErrors);
    if (!notifyModel || _hasErrors) {
      return;
    }
    widget.onChanged(
      batchSize: int.parse(_batchCtrl.text.trim()),
      throttleMs: int.parse(_throttleCtrl.text.trim()),
    );
  }
}

class ProxySettingsDraftEditor extends StatefulWidget {
  const ProxySettingsDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.onValidationChanged,
  });

  final ProxySettings value;
  final void Function({
    required String server,
    required String port,
    required String username,
    required String password,
  })
  onChanged;
  final ValueChanged<bool>? onValidationChanged;

  @override
  State<ProxySettingsDraftEditor> createState() =>
      _ProxySettingsDraftEditorState();
}

class _ProxySettingsDraftEditorState extends State<ProxySettingsDraftEditor> {
  final _validator = SettingsInputValidator();
  late final TextEditingController _serverCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  String? _portError;

  @override
  void initState() {
    super.initState();
    _serverCtrl = TextEditingController(text: widget.value.server);
    _portCtrl = TextEditingController(
      text: widget.value.port?.toString() ?? '',
    );
    _usernameCtrl = TextEditingController(text: widget.value.username);
    _passwordCtrl = TextEditingController(text: widget.value.password);
    _syncValidationState(notifyModel: false);
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
    _syncValidationState(notifyModel: false);
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
          decoration: InputDecoration(labelText: '代理端口', errorText: _portError),
          onChanged: (_) => _syncValidationState(),
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

  void _syncValidationState({bool notifyModel = true}) {
    setState(() {
      _portError = _validator.validatePortText(_portCtrl.text);
    });
    widget.onValidationChanged?.call(_portError != null);
    if (!notifyModel || _portError != null) {
      return;
    }
    widget.onChanged(
      server: _serverCtrl.text,
      port: _portCtrl.text,
      username: _usernameCtrl.text,
      password: _passwordCtrl.text,
    );
  }
}
