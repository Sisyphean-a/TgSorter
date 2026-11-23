import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class DedupMediaPreviewDialog extends StatefulWidget {
  const DedupMediaPreviewDialog({
    required this.group,
    required this.thumbnails,
    super.key,
  });

  final DuplicateMediaGroup group;
  final VideoThumbnailPreview? thumbnails;

  @override
  State<DedupMediaPreviewDialog> createState() =>
      _DedupMediaPreviewDialogState();
}

class _DedupMediaPreviewDialogState extends State<DedupMediaPreviewDialog> {
  final _frames = <VideoThumbnail>[];
  StreamSubscription<VideoThumbnail>? _session;
  String? _status;
  bool _started = false;
  bool _generating = false;

  @override
  void dispose() {
    unawaited(_session?.cancel());
    super.dispose();
  }

  void _generate(int duration) {
    setState(() {
      _started = true;
      _generating = true;
    });
    _session = widget.thumbnails!
        .generate(widget.group.copies.first.fileId, duration)
        .listen(
          (frame) {
            if (mounted) setState(() => _frames.add(frame));
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _generating = false;
                _status = '抽帧未完成：$error';
              });
            }
          },
          onDone: () {
            if (mounted) setState(() => _generating = false);
          },
          cancelOnError: true,
        );
  }

  void _stop() {
    unawaited(_session?.cancel());
    setState(() {
      _generating = false;
      _status = '已停止抽帧';
    });
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.group.copies.first;
    final isVideo = first.kind == DedupMediaKind.video;
    final isAudio =
        first.kind == DedupMediaKind.audio ||
        first.kind == DedupMediaKind.voiceNote;
    final duration = first.durationSeconds ?? 0;
    final count = isVideo && duration > 0
        ? videoThumbnailPositions(duration).length
        : 0;
    Uint8List? cover;
    for (final copy in widget.group.copies) {
      final data = copy.inlineThumbnail;
      if (data == null || data.isEmpty) continue;
      try {
        cover = base64Decode(data);
        break;
      } on FormatException {
        // 单条内嵌封面损坏时仍可显示同标识消息随附的封面。
      }
    }
    return AlertDialog(
      title: Text('预览${first.kind.label}'),
      contentTextStyle: Theme.of(context).textTheme.bodyMedium,
      content: SizedBox(
        width: 640,
        height: 300,
        child: ListView(
          children: [
            if (_frames.isEmpty && cover != null)
              Image.memory(
                cover,
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('封面无法显示'),
              )
            else if (_frames.isEmpty && !isAudio)
              const Center(child: Text('没有内嵌封面')),
            if (isAudio) ...[
              if (first.audioTitle?.isNotEmpty == true) Text(first.audioTitle!),
              if (first.audioPerformer?.isNotEmpty == true)
                Text(first.audioPerformer!),
              Text(
                duration > 0
                    ? '时长：${_timestamp(Duration(seconds: duration))}'
                    : '时长未知',
              ),
              const Text('仅显示音频信息，不下载或播放'),
            ],
            if (_frames.isNotEmpty)
              Wrap(
                spacing: AppTokens.spaceSm,
                runSpacing: AppTokens.spaceSm,
                children: [
                  for (final frame in _frames)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.memory(
                          frame.bytes,
                          width: 144,
                          height: 82,
                          fit: BoxFit.contain,
                          cacheWidth: 480,
                        ),
                        Text(_timestamp(frame.position)),
                      ],
                    ),
                ],
              ),
            if (isVideo) ...[
              const SizedBox(height: AppTokens.spaceMd),
              if (_generating) const LinearProgressIndicator(),
              Semantics(
                liveRegion: true,
                child: Text(
                  _status ??
                      (duration <= 0
                          ? '没有视频时长，无法抽帧'
                          : widget.thumbnails == null
                          ? '当前不支持时间缩略图'
                          : _started
                          ? '已生成 ${_frames.length} / $count 张'
                          : '计划 $count 张 · 分段读取上限 ${VideoThumbnailPreview.downloadBudgetMiB} MiB'),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭预览'),
        ),
        if (_generating)
          TextButton(onPressed: _stop, child: const Text('停止抽帧'))
        else if (isVideo &&
            !_started &&
            duration > 0 &&
            widget.thumbnails != null)
          FilledButton.tonal(
            onPressed: () => _generate(duration),
            child: const Text('生成时间缩略图'),
          ),
      ],
    );
  }
}

String _timestamp(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return value.inHours == 0
      ? '$minutes:$seconds'
      : '${value.inHours}:$minutes:$seconds';
}
