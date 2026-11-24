import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class DedupVideoComparisonPage extends StatefulWidget {
  const DedupVideoComparisonPage({
    required this.group,
    required this.preview,
    required this.keepId,
    super.key,
  });

  final DuplicateMediaGroup group;
  final VideoThumbnailPreview? preview;
  final int? keepId;

  @override
  State<DedupVideoComparisonPage> createState() =>
      _DedupVideoComparisonPageState();
}

class _DedupVideoComparisonPageState extends State<DedupVideoComparisonPage> {
  late final _source = widget.group.copies.firstWhere(
    (copy) => (copy.durationSeconds ?? 0) > 0,
    orElse: () => widget.group.copies.first,
  );
  late final _duration = _source.durationSeconds ?? 0;
  late final _positions = _duration > 0
      ? videoThumbnailPositions(_duration)
      : <Duration>[];
  late int? _keep = widget.keepId;
  late DedupMedia _left = widget.group.copies.firstWhere(
    (copy) => copy.messageId == _keep,
    orElse: () => widget.group.copies.first,
  );
  late DedupMedia _right = widget.group.copies.firstWhere(
    (copy) => copy != _left,
  );
  final _budget = VideoThumbnailBudget();
  final _frames = <Duration, VideoThumbnail>{};
  StreamSubscription<VideoThumbnail>? _subscription;
  VideoThumbnailPhase? _phase;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _start() {
    setState(() {
      _busy = true;
      _phase = VideoThumbnailPhase.reading;
      _error = null;
    });
    _subscription = widget.preview!
        .generate(
          _source.fileId,
          _duration,
          positions: _positions
              .where((position) => !_frames.containsKey(position))
              .toList(),
          budget: _budget,
          onPhase: (phase) {
            if (mounted && _busy) setState(() => _phase = phase);
          },
        )
        .listen(
          (frame) {
            if (mounted) setState(() => _frames[frame.position] = frame);
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _busy = false;
              _error = error is TimeoutException
                  ? error.message
                  : error is StateError
                  ? error.message.toString()
                  : '无法生成时间缩略图';
            });
          },
          onDone: () {
            if (mounted) setState(() => _busy = false);
          },
          cancelOnError: true,
        );
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = '已停止抽帧';
    });
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = widget.preview == null || _positions.isEmpty;
    final complete =
        _positions.isNotEmpty && _frames.length == _positions.length;
    final status = widget.preview == null
        ? '当前不支持时间缩略图'
        : _positions.isEmpty
        ? '没有视频时长，无法抽帧'
        : _busy
        ? (_phase == VideoThumbnailPhase.decoding ? '正在解码画面' : '正在读取视频分段')
        : _error ?? (complete ? '抽帧完成' : '同一视频只抽帧一次，两栏共用画面');
    return Scaffold(
      appBar: AppBar(
        title: const Text('对比视频'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppTokens.spaceSm),
                children: [
                  RadioGroup<int>(
                    groupValue: _keep,
                    onChanged: (id) => setState(() => _keep = id),
                    child: _pair(
                      _message(
                        context,
                        _left,
                        _right,
                        (copy) => setState(() => _left = copy),
                      ),
                      _message(
                        context,
                        _right,
                        _left,
                        (copy) => setState(() => _right = copy),
                      ),
                    ),
                  ),
                  const Divider(height: AppTokens.spaceLg),
                  for (final position in _positions) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        videoFrameTimestamp(position),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: AppTokens.spaceXs),
                    _pair(
                      _image(context, position, _left),
                      _image(context, position, _right),
                    ),
                    const SizedBox(height: AppTokens.spaceMd),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(liveRegion: true, child: Text(status)),
                  if (!unavailable)
                    Text(
                      '已生成 ${_frames.length} / ${_positions.length} 张 · 共用 ${VideoThumbnailPreview.downloadBudgetMiB} MiB 分段上限',
                    ),
                  const SizedBox(height: AppTokens.spaceXs),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppTokens.spaceXs,
                    runSpacing: AppTokens.spaceXs,
                    children: [
                      if (_busy)
                        TextButton(onPressed: _stop, child: const Text('停止抽帧'))
                      else if (!unavailable && !complete)
                        OutlinedButton(
                          onPressed: _budget.remainingBytes <= 0
                              ? null
                              : _start,
                          child: Text(
                            _budget.remainingBytes <= 0
                                ? '已用完分段额度'
                                : _error == null
                                ? '生成时间缩略图'
                                : '重试未完成时间点',
                          ),
                        ),
                      FilledButton(
                        onPressed: _keep == null || _keep == widget.keepId
                            ? null
                            : () => Navigator.of(context).pop(_keep),
                        child: const Text('确认保留项'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pair(Widget first, Widget second) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: AppTokens.spaceXs),
      Expanded(child: second),
    ],
  );

  Widget _message(
    BuildContext context,
    DedupMedia copy,
    DedupMedia other,
    ValueChanged<DedupMedia> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.group.copies.length > 2)
        DropdownButton<DedupMedia>(
          isExpanded: true,
          value: copy,
          items: [
            for (final item in widget.group.copies)
              DropdownMenuItem(
                value: item,
                enabled: item != other,
                child: Text('消息 ${item.messageId}'),
              ),
          ],
          onChanged: (item) {
            if (item != null) change(item);
          },
        )
      else
        Text(
          '消息 ${copy.messageId}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      Text(copy.sentAt.toLocal().toString().substring(0, 19)),
      RadioListTile<int>(
        contentPadding: EdgeInsets.zero,
        value: copy.messageId,
        title: Text(_keep == copy.messageId ? '已选保留' : '保留此条'),
      ),
      if (copy.caption.isNotEmpty) Text(copy.caption),
    ],
  );

  Widget _image(BuildContext context, Duration position, DedupMedia copy) {
    final frame = _frames[position];
    final label = '放大消息 ${copy.messageId} · ${videoFrameTimestamp(position)}';
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: frame == null
            ? Center(child: Text(_busy ? '等待画面' : '尚无画面'))
            : Tooltip(
                message: label,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          appBar: AppBar(
                            title: Text(
                              '消息 ${copy.messageId} · ${videoFrameTimestamp(position)}',
                            ),
                          ),
                          body: SafeArea(
                            child: InteractiveViewer(
                              maxScale: 5,
                              child: Center(child: Image.memory(frame.bytes)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: Image.memory(
                      frame.bytes,
                      fit: BoxFit.contain,
                      cacheWidth: 480,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

String videoFrameTimestamp(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return value.inHours == 0
      ? '$minutes:$seconds'
      : '${value.inHours}:$minutes:$seconds';
}
