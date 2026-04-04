import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_actions.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

class MessagePreviewImageGallery extends StatelessWidget {
  const MessagePreviewImageGallery({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.fallbackText,
    this.fileActions = const PlatformFileActions(),
  });

  final List<MediaItemPreview> items;
  final int initialIndex;
  final String fallbackText;
  final PlatformFileActions fileActions;

  int get _safeInitialIndex {
    if (items.isEmpty) {
      return 0;
    }
    if (initialIndex < 0 || initialIndex >= items.length) {
      return 0;
    }
    return initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _safeInitialIndex;
    final current = items[safeIndex];
    final previewPath = current.previewPath ?? current.fullPath;
    return MessageMediaShell(
      header: const _ImageHeader(),
      actions: [
        MessageMediaAction(
          icon: Icons.zoom_out_map_rounded,
          label: '查看大图',
          onPressed: (_) => _openGallery(context),
        ),
      ],
      moreActions: _buildMoreActions(current),
      footer: items.length > 1
          ? Text('共 ${items.length} 张，点击进入画廊查看')
          : const Text('点击进入大图预览'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openGallery(context),
        child: PreviewImage(imagePath: previewPath, fallbackText: fallbackText),
      ),
    );
  }

  List<MessageMediaAction> _buildMoreActions(MediaItemPreview item) {
    final path = item.fullPath ?? item.previewPath;
    return [
      if (fileActions.canOpenFile(path))
        MessageMediaAction(
          icon: Icons.open_in_new_rounded,
          label: '打开原图',
          onPressed: (context) => fileActions.openFile(context, path!),
        ),
      if (fileActions.canRevealInFolder(path))
        MessageMediaAction(
          icon: Icons.folder_open_rounded,
          label: '定位文件',
          onPressed: (context) => fileActions.revealInFolder(context, path!),
        ),
      if (fileActions.canCopyPath(path))
        MessageMediaAction(
          icon: Icons.copy_rounded,
          label: '复制路径',
          onPressed: (context) => fileActions.copyPath(context, path!),
        ),
    ];
  }

  Future<void> _openGallery(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'image-gallery',
      barrierDismissible: true,
      barrierColor: Colors.black87,
      pageBuilder: (context, _, _) {
        return _ImageGalleryDialog(
          items: items,
          initialIndex: _safeInitialIndex,
          fileActions: fileActions,
        );
      },
    );
  }
}

class _ImageGalleryDialog extends StatefulWidget {
  const _ImageGalleryDialog({
    required this.items,
    required this.initialIndex,
    required this.fileActions,
  });

  final List<MediaItemPreview> items;
  final int initialIndex;
  final PlatformFileActions fileActions;

  @override
  State<_ImageGalleryDialog> createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<_ImageGalleryDialog> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  MediaItemPreview get _current => widget.items[_index];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _current.fullPath ?? _current.previewPath;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_index + 1} / ${widget.items.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.fileActions.canOpenFile(path))
                    IconButton(
                      tooltip: '打开原图',
                      onPressed: () =>
                          widget.fileActions.openFile(context, path!),
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.fileActions.canRevealInFolder(path))
                    IconButton(
                      tooltip: '定位文件',
                      onPressed: () =>
                          widget.fileActions.revealInFolder(context, path!),
                      icon: const Icon(
                        Icons.folder_open_rounded,
                        color: Colors.white,
                      ),
                    ),
                  if (widget.fileActions.canCopyPath(path))
                    IconButton(
                      tooltip: '复制路径',
                      onPressed: () =>
                          widget.fileActions.copyPath(context, path!),
                      icon: const Icon(Icons.copy_rounded, color: Colors.white),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const Key('message-preview-image-gallery-pager'),
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (value) {
                  setState(() {
                    _index = value;
                  });
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final imagePath = item.fullPath ?? item.previewPath;
                  if (imagePath == null || imagePath.isEmpty) {
                    return const Center(
                      child: Text(
                        '图片尚未就绪',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }
                  return InteractiveViewer(
                    key: ValueKey('message-preview-image-zoom-$index'),
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.file(
                        io.File(imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (_, error, stackTrace) => const Text(
                          '图片加载失败',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (widget.items.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    IconButton.filled(
                      onPressed: _index > 0
                          ? () => _controller.previousPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      onPressed: _index + 1 < widget.items.length
                          ? () => _controller.nextPage(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                            )
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  const _ImageHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('图片预览'),
        SizedBox(height: 2),
        Text('支持大图查看、切换和文件动作', style: TextStyle(fontSize: 12)),
      ],
    );
  }
}
