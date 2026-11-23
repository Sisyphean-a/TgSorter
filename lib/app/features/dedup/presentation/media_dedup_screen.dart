import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/features/dedup/presentation/dedup_media_preview_dialog.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class MediaDedupScreen extends StatefulWidget {
  const MediaDedupScreen({required this.workbench, super.key});

  final MediaDedupWorkbench workbench;

  @override
  State<MediaDedupScreen> createState() => _MediaDedupScreenState();
}

class _MediaDedupScreenState extends State<MediaDedupScreen> {
  SelectableChat? _chat;
  final _groups = <DuplicateMediaGroup>[];
  final _keepChoices = <DuplicateMediaGroup, int>{};
  DuplicateMediaGroup? _focused;
  DedupScanStop? _scanStop;
  DedupScanCheckpoint? _checkpoint;
  String? _progress;
  String? _notice;
  String? _error;
  bool _loadingChats = false;
  bool _deleting = false;
  bool _scanned = false;
  int _unidentified = 0;

  bool get _busy => _deleting || _loadingChats || _scanStop != null;

  @override
  void dispose() {
    _scanStop?.cancel();
    super.dispose();
  }

  void _resetResults() {
    _groups.clear();
    _keepChoices.clear();
    _focused = null;
    _scanned = false;
    _unidentified = 0;
    _checkpoint = null;
  }

  Future<void> _pickChat() async {
    setState(() {
      _loadingChats = true;
      _error = null;
    });
    try {
      final chats = await widget.workbench.listChats();
      if (!mounted) return;
      setState(() => _loadingChats = false);
      final selected = await showDialog<SelectableChat>(
        context: context,
        builder: (_) => _ChatPicker(chats: chats),
      );
      if (!mounted || selected == null || selected.id == _chat?.id) return;
      setState(() {
        _chat = selected;
        _resetResults();
        _notice = null;
      });
      await _scan();
    } catch (error) {
      if (mounted) setState(() => _error = '读取会话失败，请重试：$error');
    } finally {
      if (mounted && _loadingChats) setState(() => _loadingChats = false);
    }
  }

  Future<void> _scan() async {
    final chat = _chat!;
    final stop = DedupScanStop();
    setState(() {
      _scanStop = stop;
      _notice = null;
      _error = null;
    });
    try {
      final result = await widget.workbench.scan(
        chat.id,
        stop: stop,
        resumeFrom: _checkpoint,
        onProgress: (inspected) {
          if (mounted) {
            setState(() => _progress = '正在读取会话历史 · 已检查 $inspected 个媒体');
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _resetResults();
        _groups.addAll(result.groups);
        _scanned = true;
        _unidentified = result.unidentified;
      });
    } on DedupScanInterrupted catch (error) {
      if (!mounted) return;
      setState(() {
        _resetResults();
        _checkpoint = error.checkpoint;
      });
    } on DedupScanCancelled {
      if (!mounted) return;
      setState(() {
        _resetResults();
        _notice = '扫描已停止';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resetResults();
        _error = '扫描未完成，请重试：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _scanStop = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _remove(DuplicateMediaGroup group, int keepId) async {
    final keep = group.copies.singleWhere((item) => item.messageId == keepId);
    final count = group.copies.length - 1;
    final captions = group.copies
        .where((item) => item != keep && item.caption.isNotEmpty)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除 $count 条重复消息？'),
        contentTextStyle: Theme.of(context).textTheme.bodyMedium,
        content: SingleChildScrollView(
          child: Text(
            '会话：${_chat!.title}（${keep.chatId}）\n保留：${_messageLabel(keep)}\n'
            '${captions == 0 ? '' : '其中 $captions 条附有说明，说明也会删除。\n'}'
            '删除对会话中的所有人生效，无法撤销。',
          ),
        ),
        actions: [
          TextButton(
            style: _secondaryActionStyle(context),
            autofocus: true,
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _dangerColor(context),
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除 $count 条消息'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _notice = null;
      _error = null;
    });
    try {
      final removed = await widget.workbench.removeDuplicates(group, keepId);
      if (!mounted) return;
      setState(() {
        _groups.remove(group);
        _keepChoices.remove(group);
        _focused = null;
        _notice = '已删除 $removed 条重复消息';
      });
    } on DedupDeletionUncertain catch (failure) {
      if (!mounted) return;
      setState(() {
        _resetResults();
        _error = '未能确认删除结果，请重新扫描后再处理：${failure.error}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = '未发出删除请求：$error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    final scanning = _scanStop != null;
    final activity =
        _progress ??
        (_deleting
            ? '正在核对并删除消息'
            : _loadingChats
            ? '正在读取会话'
            : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          child: Row(
            children: [
              Flexible(
                child: OutlinedButton(
                  onPressed: _busy ? null : _pickChat,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_outlined),
                      const SizedBox(width: AppTokens.spaceSm),
                      Flexible(
                        child: Tooltip(
                          message: chat == null
                              ? '选择会话'
                              : '${chat.title}（${chat.id}）',
                          child: Text(
                            chat?.title ?? '选择会话',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.spaceSm),
              if (scanning)
                TextButton(
                  style: _secondaryActionStyle(context),
                  onPressed: _scanStop!.cancel,
                  child: const Text('停止扫描'),
                )
              else
                FilledButton(
                  style: _primaryActionStyle(context),
                  onPressed: chat == null || _busy ? null : _scan,
                  child: Text(
                    _checkpoint != null
                        ? '继续扫描'
                        : _scanned
                        ? '重新扫描'
                        : '扫描会话',
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (_groups.isEmpty) {
                final title = chat == null
                    ? '未选择会话'
                    : scanning
                    ? '扫描进行中'
                    : _checkpoint != null
                    ? '读取会话历史超时'
                    : !_scanned
                    ? '等待扫描'
                    : '没有待处理的同标识副本';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTokens.spaceMd),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (!_scanned && !scanning)
                          Text(
                            _checkpoint != null
                                ? '已检查 ${_checkpoint!.inspected} 个媒体，可从当前位置继续。'
                                : chat == null
                                ? '选择要整理的会话'
                                : '仅检查 Telegram 文件标识，不下载媒体',
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                );
              }
              final wide = constraints.maxWidth >= 900;
              final focused = _focused;
              if (!wide) {
                return focused == null
                    ? _results()
                    : _details(focused, canGoBack: true);
              }
              return Row(
                children: [
                  Flexible(flex: 1, child: _results()),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 2,
                    child: focused == null
                        ? const Center(child: Text('选择一组重复媒体'))
                        : _details(focused, canGoBack: false),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: AppTokens.spaceXs,
          child: activity == null ? null : const LinearProgressIndicator(),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          child: Semantics(
            liveRegion: activity == null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (activity != null || _scanned || _notice != null)
                  Text(
                    activity ??
                        [
                          if (_scanned)
                            '${_groups.length} 组待处理${_unidentified == 0 ? '' : ' · $_unidentified 个缺少文件标识'}',
                          ?_notice,
                        ].join(' · '),
                  ),
                if (_error != null)
                  Tooltip(
                    message: _error!,
                    child: Text(
                      _error!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _dangerColor(context)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _results() => ListView.separated(
    key: const PageStorageKey('dedup-results'),
    itemCount: _groups.length,
    separatorBuilder: (_, _) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final group = _groups[index];
      return ListTile(
        leading: Icon(switch (group.kind) {
          DedupMediaKind.photo => Icons.photo_outlined,
          DedupMediaKind.video => Icons.video_library_outlined,
          DedupMediaKind.audio => Icons.audiotrack_rounded,
          DedupMediaKind.voiceNote => Icons.mic_none_rounded,
        }),
        title: Text('${group.kind.label} · ${group.copies.length} 份'),
        subtitle: Text(
          '${group.size == null ? '大小未知' : _formatSize(group.size!)} · ${_formatDate(group.copies.first.sentAt)}',
        ),
        iconColor: Theme.of(context).colorScheme.onSurface,
        selected: _focused == group,
        selectedColor: Theme.of(context).colorScheme.onSurface,
        selectedTileColor: AppTokens.colorsOf(context).brandAccentSoft,
        enabled: !_busy,
        onTap: () => setState(() => _focused = group),
      );
    },
  );

  Widget _details(DuplicateMediaGroup group, {required bool canGoBack}) {
    final keep = _keepChoices[group];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTokens.spaceSm),
          child: Row(
            children: [
              if (canGoBack)
                IconButton(
                  tooltip: '返回重复列表',
                  onPressed: () => setState(() => _focused = null),
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    '${group.kind.label} · ${group.copies.length} 份',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              TextButton(
                style: _secondaryActionStyle(context),
                onPressed: _busy ? null : () => _showPreview(group),
                child: Text('预览${group.kind.label}'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: RadioGroup<int>(
            groupValue: keep,
            onChanged: (id) {
              if (id != null && !_busy) {
                setState(() => _keepChoices[group] = id);
              }
            },
            child: ListView.separated(
              key: ValueKey(group),
              itemCount: group.copies.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = group.copies[index];
                return RadioListTile<int>(
                  enabled: !_busy,
                  value: item.messageId,
                  title: Text(_formatDate(item.sentAt)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('消息 ${item.messageId}'),
                      if (item.caption.isNotEmpty) Text(item.caption),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppTokens.spaceSm),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppTokens.spaceSm,
              runSpacing: AppTokens.spaceXs,
              children: [
                Text(keep == null ? '选择要保留的一份' : '保留消息 $keep'),
                FilledButton.tonal(
                  style: _primaryActionStyle(context),
                  onPressed: keep == null || _busy
                      ? null
                      : () => _remove(group, keep),
                  child: const Text('删除其余副本'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPreview(DuplicateMediaGroup group) => showDialog<void>(
    context: context,
    builder: (_) => DedupMediaPreviewDialog(
      group: group,
      thumbnails: widget.workbench.videoThumbnails,
    ),
  );
}

class _ChatPicker extends StatefulWidget {
  const _ChatPicker({required this.chats});

  final List<SelectableChat> chats;

  @override
  State<_ChatPicker> createState() => _ChatPickerState();
}

class _ChatPickerState extends State<_ChatPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final chats = widget.chats
        .where((chat) => chat.title.toLowerCase().contains(_query))
        .toList(growable: false);
    return AlertDialog(
      title: const Text('选择会话'),
      content: SizedBox(
        width: 420,
        height: 320,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '搜索会话',
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            Expanded(
              child: chats.isEmpty
                  ? Center(
                      child: Text(widget.chats.isEmpty ? '未找到可用会话' : '没有匹配的会话'),
                    )
                  : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return ListTile(
                          title: Tooltip(
                            message: chat.title,
                            child: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          subtitle: Text('会话 ${chat.id}'),
                          onTap: () => Navigator.of(context).pop(chat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: _secondaryActionStyle(context),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

ButtonStyle _primaryActionStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    foregroundColor: colors.brightness == Brightness.light
        ? colors.onSurface
        : colors.onPrimary,
  );
}

ButtonStyle _secondaryActionStyle(BuildContext context) => TextButton.styleFrom(
  foregroundColor: Theme.of(context).colorScheme.onSurface,
);

Color _dangerColor(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return colors.brightness == Brightness.light
      ? const Color(0xFFBD403B)
      : colors.error;
}

String _formatDate(DateTime value) =>
    value.toLocal().toString().substring(0, 19);

String _messageLabel(DedupMedia item) =>
    '${_formatDate(item.sentAt)} · 消息 ${item.messageId}';

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '$bytes B';
}
