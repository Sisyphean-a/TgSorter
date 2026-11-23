import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class DedupPhotoComparisonDialog extends StatefulWidget {
  const DedupPhotoComparisonDialog({
    required this.group,
    required this.keepId,
    required this.onKeepChanged,
    required this.loadPhotoFile,
    super.key,
  });

  final DuplicateMediaGroup group;
  final int? keepId;
  final ValueChanged<int> onKeepChanged;
  final Future<String> Function(int fileId) loadPhotoFile;

  @override
  State<DedupPhotoComparisonDialog> createState() =>
      _DedupPhotoComparisonDialogState();
}

class _DedupPhotoComparisonDialogState
    extends State<DedupPhotoComparisonDialog> {
  late int? _keepId = widget.keepId;
  final _files = <int, Future<String>>{};

  Future<String> _load(int fileId) => _files.putIfAbsent(fileId, () async {
    try {
      return await widget.loadPhotoFile(fileId);
    } catch (_) {
      _files.remove(fileId);
      rethrow;
    }
  });

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('对比照片 · ${widget.group.copies.length} 份'),
    content: SizedBox(
      width: 800,
      height: 500,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final copies = widget.group.copies;
          final columns = constraints.maxWidth >= 600 ? 2 : 1;
          return RadioGroup<int>(
            groupValue: _keepId,
            onChanged: (id) {
              if (id == null) return;
              setState(() => _keepId = id);
              widget.onKeepChanged(id);
            },
            child: ListView.separated(
              itemCount: (copies.length + columns - 1) ~/ columns,
              separatorBuilder: (_, _) =>
                  const Divider(height: AppTokens.spaceLg),
              itemBuilder: (context, index) {
                final first = copies[index * columns];
                if (columns == 1) return _copy(context, first);
                final next = index * columns + 1;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _copy(context, first)),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: next < copies.length
                          ? _copy(context, copies[next])
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('关闭对比'),
      ),
    ],
  );

  Widget _copy(BuildContext context, DedupMedia copy) => Column(
    key: ValueKey(copy.messageId),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 176,
        child: switch (copy.photoPreviewFileId) {
          final int id => _PhotoImage(fileId: id, load: _load),
          null => const Center(child: Text('没有独立缩略图，可查看大图')),
        },
      ),
      RadioListTile<int>(
        contentPadding: EdgeInsets.zero,
        value: copy.messageId,
        title: Text(
          _keepId == copy.messageId
              ? '已选保留 · 消息 ${copy.messageId}'
              : '保留消息 ${copy.messageId}',
        ),
        subtitle: Text(copy.sentAt.toLocal().toString().substring(0, 19)),
      ),
      if (copy.caption.isNotEmpty) Text(copy.caption),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('大图 · 消息 ${copy.messageId}'),
              content: SizedBox(
                width: 800,
                height: 500,
                child: _PhotoImage(
                  fileId: copy.fileId,
                  load: _load,
                  zoom: true,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭大图'),
                ),
              ],
            ),
          ),
          child: const Text('查看大图'),
        ),
      ),
    ],
  );
}

class _PhotoImage extends StatefulWidget {
  const _PhotoImage({
    required this.fileId,
    required this.load,
    this.zoom = false,
  });

  final int fileId;
  final Future<String> Function(int) load;
  final bool zoom;

  @override
  State<_PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<_PhotoImage> {
  late Future<String> _file = widget.load(widget.fileId);

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _file,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(semanticsLabel: '正在加载照片'),
        );
      }
      if (snapshot.hasError) {
        return Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('照片加载失败'),
              TextButton(
                onPressed: () =>
                    setState(() => _file = widget.load(widget.fileId)),
                child: const Text('重试加载'),
              ),
            ],
          ),
        );
      }
      final image = Image.file(
        File(snapshot.requireData),
        fit: widget.zoom ? BoxFit.contain : BoxFit.scaleDown,
        errorBuilder: (_, _, _) => const Center(child: Text('照片无法显示')),
      );
      return widget.zoom
          ? InteractiveViewer(child: Center(child: image))
          : Center(child: image);
    },
  );
}
