import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/widgets/message_preview_helpers.dart';
import 'package:video_player/video_player.dart';

class MessagePreviewMedia extends StatelessWidget {
  const MessagePreviewMedia({
    super.key,
    required this.items,
    required this.preparing,
    required this.onRequestPlayback,
    required this.controllerInitializer,
    this.preferVideoFallback = false,
    this.fallbackImagePath,
    this.fallbackVideoPath,
    this.fallbackThumbnailPath,
  });

  final List<MediaItemPreview> items;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final VideoControllerInitializer? controllerInitializer;
  final bool preferVideoFallback;
  final String? fallbackImagePath;
  final String? fallbackVideoPath;
  final String? fallbackThumbnailPath;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      if (preferVideoFallback ||
          fallbackVideoPath != null ||
          fallbackThumbnailPath != null) {
        return MessagePreviewVideo(
          videoPath: fallbackVideoPath,
          thumbnailPath: fallbackThumbnailPath,
          preparing: preparing,
          onRequestPlayback: onRequestPlayback,
          controllerInitializer: controllerInitializer,
        );
      }
      return PreviewImage(
        imagePath: fallbackImagePath,
        fallbackText: '图片已识别（本地文件未就绪）',
      );
    }
    if (items.length == 1) {
      return _buildItem(items.single);
    }
    final allVideos = items.every((item) => item.kind == MediaItemKind.video);
    if (allVideos) {
      return Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _buildItem(items[index]),
            if (index < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: items.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 8),
            child: _buildItem(items[index]),
          );
        },
      ),
    );
  }

  Widget _buildItem(MediaItemPreview item) {
    if (item.kind == MediaItemKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewVideo(
            videoPath: item.fullPath,
            thumbnailPath: item.previewPath,
            preparing: preparing,
            onRequestPlayback: ([messageId]) =>
                onRequestPlayback(item.messageId),
            controllerInitializer: controllerInitializer,
          ),
          if (item.durationSeconds != null) ...[
            const SizedBox(height: 8),
            PreviewMetaText(
              text: '时长 ${formatPreviewDuration(item.durationSeconds!)}',
            ),
          ],
        ],
      );
    }
    return PreviewImage(
      imagePath: item.previewPath ?? item.fullPath,
      fallbackText: '图片已识别（本地文件未就绪）',
    );
  }
}

class MessagePreviewVideo extends StatefulWidget {
  const MessagePreviewVideo({
    super.key,
    required this.videoPath,
    required this.thumbnailPath,
    required this.preparing,
    required this.onRequestPlayback,
    required this.controllerInitializer,
  });

  final String? videoPath;
  final String? thumbnailPath;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final VideoControllerInitializer? controllerInitializer;

  @override
  State<MessagePreviewVideo> createState() => _MessagePreviewVideoState();
}

class _MessagePreviewVideoState extends State<MessagePreviewVideo> {
  static const Duration initializeTimeout = Duration(seconds: 5);

  VideoPlayerController? _controller;
  String? _currentPath;
  bool _loading = false;
  Timer? _retryTimer;
  bool _playbackRequested = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _syncController(allowInitialize: false);
  }

  @override
  void didUpdateWidget(covariant MessagePreviewVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _syncController(allowInitialize: _playbackRequested);
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _syncController({required bool allowInitialize}) async {
    final path = widget.videoPath;
    if (path == null || path.isEmpty || !io.File(path).existsSync()) {
      await _disposeController();
      _ensureRetryTimer(path);
      if (mounted) {
        setState(() {
          _currentPath = path;
          _loading = false;
          _errorText = null;
        });
      }
      return;
    }
    if (_currentPath == path && _controller?.value.isInitialized == true) {
      _retryTimer?.cancel();
      return;
    }
    if (!allowInitialize) {
      _retryTimer?.cancel();
      if (mounted) {
        setState(() {
          _currentPath = path;
          _loading = false;
          _errorText = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _currentPath = path;
      _errorText = null;
    });
    await _disposeController();
    final next = VideoPlayerController.file(io.File(path));
    try {
      developer.log('initialize start path=$path', name: 'VideoPreview');
      final initialize =
          widget.controllerInitializer ??
          (VideoPlayerController c) => c.initialize();
      await initialize(next).timeout(initializeTimeout);
      next.setLooping(true);
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _loading = false;
        _errorText = null;
      });
      developer.log('initialize success path=$path', name: 'VideoPreview');
      unawaited(next.play());
      _retryTimer?.cancel();
    } on TimeoutException catch (error, stackTrace) {
      developer.log(
        'initialize timeout path=$path',
        name: 'VideoPreview',
        error: error,
        stackTrace: stackTrace,
      );
      await next.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _loading = false;
        _errorText = '视频播放器初始化超时';
      });
    } catch (error, stackTrace) {
      developer.log(
        'initialize failure path=$path',
        name: 'VideoPreview',
        error: error,
        stackTrace: stackTrace,
      );
      await next.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _loading = false;
        _errorText = '视频播放失败：$error';
      });
    }
  }

  Future<void> _disposeController() async {
    final current = _controller;
    _controller = null;
    if (current != null) {
      await current.dispose();
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
      unawaited(_syncController(allowInitialize: _playbackRequested));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const PreviewPlaceholder(text: '视频加载中...');
    }
    if (_errorText case final text?) {
      return _buildErrorState(text);
    }
    final controller = _controller;
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
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: previewMediaHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        IconButton.filled(
          onPressed: () {
            if (controller.value.isPlaying) {
              controller.pause();
            } else {
              controller.play();
            }
            setState(() {});
          },
          icon: Icon(
            controller.value.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail(String path) {
    return Image.file(
      io.File(path),
      width: double.infinity,
      height: previewMediaHeight,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const PreviewPlaceholder(text: '视频缩略图加载失败'),
    );
  }

  Widget _buildPendingPreview({String? thumbnailPath}) {
    final body = thumbnailPath == null
        ? PreviewPlaceholder(
            text: widget.preparing ? '视频下载中...' : '视频已识别（点击播放开始下载）',
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(thumbnailPath),
              const ColoredBox(color: Colors.black26),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: previewMediaHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: body),
          if (widget.preparing) const CircularProgressIndicator(),
          IconButton.filled(
            onPressed: widget.preparing
                ? null
                : () async {
                    _playbackRequested = true;
                    final path = widget.videoPath;
                    final hasLocalFile =
                        path != null &&
                        path.isNotEmpty &&
                        io.File(path).existsSync();
                    if (hasLocalFile) {
                      await _syncController(allowInitialize: true);
                      return;
                    }
                    await widget.onRequestPlayback();
                  },
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String text) {
    return SizedBox(
      width: double.infinity,
      height: previewMediaHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PreviewPlaceholder(text: text),
          Positioned(
            bottom: 16,
            child: IconButton.filled(
              onPressed: () async {
                await _syncController(allowInitialize: true);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
