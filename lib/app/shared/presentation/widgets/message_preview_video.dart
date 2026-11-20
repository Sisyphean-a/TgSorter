import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/services/td_video_stream.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_actions.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_video_fullscreen.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';
import 'package:video_player/video_player.dart';

const _previewScrimColor = Color(0x14000000);
const _overlayButtonSplashColor = Color(0x1FFFFFFF);
const _overlayButtonDisabledColor = Color(0x99FFFFFF);

final _overlayIconButtonStyle = ButtonStyle(
  backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
  foregroundColor: WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return _overlayButtonDisabledColor;
    }
    return Colors.white;
  }),
  overlayColor: const WidgetStatePropertyAll(_overlayButtonSplashColor),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
);

class MessagePreviewVideo extends StatefulWidget {
  const MessagePreviewVideo({
    super.key,
    required this.videoPath,
    required this.thumbnailPath,
    required this.preparing,
    required this.onRequestPlayback,
    required this.controllerInitializer,
    this.videoFileId,
    this.loadErrorText,
    this.compact = false,
    this.height = previewMediaHeight,
    this.fileActions = const PlatformFileActions(),
  });

  final String? videoPath;
  final int? videoFileId;
  final String? thumbnailPath;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final VideoControllerInitializer? controllerInitializer;
  final String? loadErrorText;
  final bool compact;
  final double height;
  final PlatformFileActions fileActions;

  @override
  State<MessagePreviewVideo> createState() => _MessagePreviewVideoState();
}

class _MessagePreviewVideoState extends State<MessagePreviewVideo> {
  static const Duration initializeTimeout = Duration(seconds: 5);

  VideoPlayerController? _controller;
  TdVideoStreamSession? _streamSession;
  int _playbackGeneration = 0;
  bool _loading = false;
  Timer? _retryTimer;
  bool _playbackRequested = false;
  String? _errorText;
  bool _scrubbing = false;
  double? _scrubMilliseconds;
  double _speed = 1.0;
  bool _looping = true;

  @override
  void didUpdateWidget(covariant MessagePreviewVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoFileId != widget.videoFileId) {
      _resetPlayback();
    } else if (_playbackRequested &&
        oldWidget.videoPath != widget.videoPath &&
        _streamSession == null &&
        !_loading) {
      _releasePlayback();
      unawaited(_playLocalWhenReady());
    }
  }

  @override
  void dispose() {
    _resetPlayback();
    super.dispose();
  }

  void _resetPlayback() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _playbackRequested = false;
    _loading = false;
    _errorText = null;
    _scrubbing = false;
    _scrubMilliseconds = null;
    _releasePlayback();
  }

  void _releasePlayback() {
    _playbackGeneration++;
    final stream = _streamSession;
    _streamSession = null;
    if (stream != null) unawaited(stream.close());
    final current = _controller;
    _controller = null;
    current?.removeListener(_handleControllerTick);
    if (current != null) unawaited(current.dispose());
  }

  io.File? _localFile() {
    final path = widget.videoPath;
    if (path == null || path.isEmpty) return null;
    final file = io.File(path);
    return file.existsSync() ? file : null;
  }

  Future<void> _requestPlayback() async {
    _playbackRequested = true;
    final local = _localFile();
    if (local != null) {
      await _startPlayback(file: local);
    } else if (widget.videoFileId case final id?
        when Get.isRegistered<TdVideoStream>()) {
      await _startPlayback(stream: Get.find<TdVideoStream>(), fileId: id);
    } else {
      setState(() => _errorText = null);
      _ensureRetryTimer(widget.videoPath);
      await widget.onRequestPlayback();
    }
  }

  Future<void> _playLocalWhenReady() async {
    if (_loading || _controller != null || _streamSession != null) return;
    final file = _localFile();
    if (file == null) {
      _ensureRetryTimer(widget.videoPath);
      return;
    }
    await _startPlayback(file: file);
  }

  Future<void> _startPlayback({
    io.File? file,
    TdVideoStream? stream,
    int? fileId,
  }) async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _releasePlayback();
    final generation = _playbackGeneration;
    bool active() => mounted && generation == _playbackGeneration;
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      if (stream != null) {
        final session = await stream.open(fileId!);
        if (!active()) {
          await session.close();
          return;
        }
        _streamSession = session;
      }
      final uri = _streamSession?.uri;
      final next = uri != null && uri.scheme != 'file'
          ? VideoPlayerController.networkUrl(uri)
          : VideoPlayerController.file(file ?? io.File.fromUri(uri!));
      _controller = next;
      final initialize =
          widget.controllerInitializer ??
          (VideoPlayerController c) => c.initialize();
      await initialize(next).timeout(
        uri != null && uri.scheme != 'file'
            ? const Duration(seconds: 25)
            : initializeTimeout,
      );
      if (!active()) return;
      await next.setLooping(_looping);
      if (!active()) return;
      await next.setPlaybackSpeed(_speed);
      if (!active()) return;
      next.addListener(_handleControllerTick);
      await next.play();
      if (active()) setState(() => _loading = false);
    } catch (error, stackTrace) {
      if (!active()) return;
      developer.log(
        '视频播放初始化失败',
        name: 'VideoPreview',
        error: error,
        stackTrace: stackTrace,
      );
      _releasePlayback();
      setState(() {
        _loading = false;
        _errorText = error is TimeoutException ? '视频加载超时，请重试' : '视频播放失败，请重试';
      });
    }
  }

  void _handleControllerTick() {
    if (!mounted || _scrubbing) {
      return;
    }
    setState(() {});
  }

  Future<void> _seekTo(
    VideoPlayerController controller,
    Duration target,
  ) async {
    final duration = controller.value.duration;
    final clamped = clampVideoSeekTarget(target: target, duration: duration);
    await controller.seekTo(clamped);
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final value = controller.value;
    final target = value.position + Duration(seconds: seconds);
    await _seekTo(controller, target);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.setPlaybackSpeed(speed);
    if (mounted) {
      setState(() {
        _speed = speed;
      });
    }
  }

  Future<void> _toggleLooping() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final nextValue = !_looping;
    await controller.setLooping(nextValue);
    if (mounted) {
      setState(() {
        _looping = nextValue;
      });
    }
  }

  void _ensureRetryTimer(String? path) {
    final hasPath = path != null && path.isNotEmpty;
    if (!hasPath) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    if (_retryTimer != null) {
      return;
    }
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      unawaited(_playLocalWhenReady());
    });
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    await showAdaptiveVideoFullscreenDialog<void>(
      context: context,
      aspectRatio: controller.value.aspectRatio,
      builder: (context) {
        return MessagePreviewVideoFullscreen(
          controller: controller,
          onClose: () => Navigator.of(context).pop(),
          onSeekBy: _seekBy,
          onTogglePlayback: _togglePlayback,
          onToggleLooping: () {
            unawaited(_toggleLooping());
          },
          onSetPlaybackSpeed: _setPlaybackSpeed,
          currentSpeed: _speed,
          looping: _looping,
          trailingActions: _buildFullscreenActions(context),
        );
      },
    );
  }

  List<Widget> _buildFullscreenActions(BuildContext context) {
    final path = widget.videoPath;
    return [
      if (widget.fileActions.canOpenFile(path))
        IconButton(
          tooltip: '打开原文件',
          onPressed: () => widget.fileActions.openFile(context, path!),
          icon: const Icon(Icons.open_in_new_rounded, color: Colors.white),
        ),
      if (widget.fileActions.canRevealInFolder(path))
        IconButton(
          tooltip: '定位文件',
          onPressed: () => widget.fileActions.revealInFolder(context, path!),
          icon: const Icon(Icons.folder_open_rounded, color: Colors.white),
        ),
    ];
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.value.isPlaying) {
      unawaited(controller.pause());
    } else {
      unawaited(controller.play());
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildBody(context);
    }
    return MessageMediaShell(
      actions: _buildPrimaryActions(),
      moreActions: _buildMoreActions(),
      footer: _buildFooter(context),
      child: _buildBody(context),
    );
  }

  List<MessageMediaAction> _buildPrimaryActions() {
    if (widget.compact) {
      return const <MessageMediaAction>[];
    }
    final controller = _controller;
    return [
      if (controller != null && controller.value.isInitialized)
        MessageMediaAction(
          icon: Icons.fullscreen_rounded,
          label: '全屏',
          onPressed: (_) => _openFullscreen(),
        ),
    ];
  }

  List<MessageMediaAction> _buildMoreActions() {
    if (widget.compact) {
      return const <MessageMediaAction>[];
    }
    final path = widget.videoPath;
    return [
      if (widget.fileActions.canOpenFile(path))
        MessageMediaAction(
          icon: Icons.open_in_new_rounded,
          label: '打开原文件',
          onPressed: (context) => widget.fileActions.openFile(context, path!),
        ),
      if (widget.fileActions.canRevealInFolder(path))
        MessageMediaAction(
          icon: Icons.folder_open_rounded,
          label: '定位文件',
          onPressed: (context) =>
              widget.fileActions.revealInFolder(context, path!),
        ),
      if (widget.fileActions.canCopyPath(path))
        MessageMediaAction(
          icon: Icons.copy_rounded,
          label: '复制路径',
          onPressed: (context) => widget.fileActions.copyPath(context, path!),
        ),
    ];
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const PreviewPlaceholder(text: '视频加载中...');
    }
    if (widget.loadErrorText case final text?) {
      return _buildErrorState(text);
    }
    if (_errorText case final text?) {
      return _buildErrorState(text);
    }
    final controller = _controller;
    if (controller?.value.hasError == true) {
      return _buildErrorState('视频播放中断，请重试');
    }
    if (controller == null || !controller.value.isInitialized) {
      final thumb = widget.thumbnailPath;
      if (thumb != null && thumb.isNotEmpty) {
        return _buildPendingPreview(thumbnailPath: thumb);
      }
      return _buildPendingPreview();
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          height: widget.height,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        if (controller.value.isBuffering)
          const Positioned(
            right: 12,
            bottom: 12,
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        IconButton(
          key: const Key('message-preview-video-play-toggle'),
          onPressed: _togglePlayback,
          style: _overlayIconButtonStyle,
          icon: Icon(
            controller.value.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
        ),
      ],
    );
  }

  Widget? _buildFooter(BuildContext context) {
    if (widget.compact) {
      return null;
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    final value = controller.value;
    final duration = value.duration;
    final hasDuration = duration > Duration.zero;
    final livePosition = hasDuration
        ? clampVideoSeekTarget(target: value.position, duration: duration)
        : Duration.zero;
    final effectivePosition = hasDuration && _scrubMilliseconds != null
        ? clampVideoSeekTarget(
            target: Duration(milliseconds: _scrubMilliseconds!.round()),
            duration: duration,
          )
        : livePosition;
    final maxMilliseconds = hasDuration
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final sliderValue = hasDuration
        ? effectivePosition.inMilliseconds.toDouble().clamp(
            0.0,
            maxMilliseconds,
          )
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: hasDuration ? () => _seekBy(-10) : null,
              icon: const Icon(Icons.replay_10_rounded),
            ),
            Expanded(
              child: Slider(
                value: sliderValue,
                min: 0,
                max: maxMilliseconds,
                allowedInteraction: SliderInteraction.tapAndSlide,
                onChangeStart: hasDuration
                    ? (nextValue) {
                        setState(() {
                          _scrubbing = true;
                          _scrubMilliseconds = nextValue;
                        });
                      }
                    : null,
                onChanged: hasDuration
                    ? (nextValue) {
                        setState(() {
                          _scrubMilliseconds = nextValue;
                        });
                      }
                    : null,
                onChangeEnd: hasDuration
                    ? (nextValue) {
                        final target = Duration(
                          milliseconds: nextValue.round(),
                        );
                        unawaited(() async {
                          try {
                            await _seekTo(controller, target);
                          } finally {
                            if (mounted) {
                              setState(() {
                                _scrubbing = false;
                                _scrubMilliseconds = null;
                              });
                            }
                          }
                        }());
                      }
                    : null,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: hasDuration ? () => _seekBy(10) : null,
              icon: const Icon(Icons.forward_10_rounded),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              '${formatPreviewDuration(effectivePosition.inSeconds)} / ${formatPreviewDuration(duration.inSeconds)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const Spacer(),
            PopupMenuButton<double>(
              key: const Key('message-preview-video-speed-menu'),
              tooltip: '播放速度',
              initialValue: _speed,
              onSelected: _setPlaybackSpeed,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 0.5, child: Text('0.5x')),
                PopupMenuItem(value: 1.0, child: Text('1.0x')),
                PopupMenuItem(value: 1.5, child: Text('1.5x')),
                PopupMenuItem(value: 2.0, child: Text('2.0x')),
              ],
              child: _FooterChip(
                label:
                    '${_speed.toStringAsFixed(_speed == _speed.roundToDouble() ? 0 : 1)}x',
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              key: const Key('message-preview-video-loop-chip'),
              label: const Text('循环'),
              selected: _looping,
              onSelected: (_) => _toggleLooping(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThumbnail(String path) {
    return Image.file(
      io.File(path),
      width: double.infinity,
      height: widget.height,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) =>
          const PreviewPlaceholder(text: '视频缩略图加载失败'),
    );
  }

  Widget _buildPendingPreview({String? thumbnailPath}) {
    final body = thumbnailPath == null
        ? PreviewPlaceholder(
            text: widget.preparing ? '后台准备中，待本地文件完成后自动起播' : '点击播放',
            height: widget.height,
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(thumbnailPath),
              const ColoredBox(color: _previewScrimColor),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: body),
          if (widget.preparing) const CircularProgressIndicator(),
          IconButton(
            key: const Key('message-video-play'),
            onPressed: widget.preparing ? null : _requestPlayback,
            style: _overlayIconButtonStyle,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String text) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PreviewPlaceholder(text: text, height: widget.height),
          Positioned(
            bottom: 16,
            child: IconButton(
              onPressed: _requestPlayback,
              style: _overlayIconButtonStyle,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  const _FooterChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label),
      ),
    );
  }
}
