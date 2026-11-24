import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/dedup/presentation/dedup_video_comparison_page.dart'
    show videoFrameTimestamp;

class DedupMediaPreviewDialog extends StatelessWidget {
  const DedupMediaPreviewDialog({required this.group, super.key});

  final DuplicateMediaGroup group;

  @override
  Widget build(BuildContext context) {
    final first = group.copies.first;
    final duration = first.durationSeconds ?? 0;
    Uint8List? cover;
    for (final copy in group.copies) {
      final data = copy.inlineThumbnail;
      if (data == null || data.isEmpty) continue;
      try {
        cover = base64Decode(data);
        break;
      } on FormatException {
        // 继续尝试同标识消息随附的封面。
      }
    }
    return AlertDialog(
      title: Text('预览${first.kind.label}'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover != null)
              Image.memory(
                cover,
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('封面无法显示'),
              ),
            if (first.audioTitle?.isNotEmpty == true) Text(first.audioTitle!),
            if (first.audioPerformer?.isNotEmpty == true)
              Text(first.audioPerformer!),
            Text(
              duration > 0
                  ? '时长：${videoFrameTimestamp(Duration(seconds: duration))}'
                  : '时长未知',
            ),
            const Text('仅显示音频信息，不下载或播放'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭预览'),
        ),
      ],
    );
  }
}
