import 'dart:io' as io;
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

typedef VideoControllerInitializer =
    Future<void> Function(VideoPlayerController controller);

class MessageViewerCard extends StatelessWidget {
  const MessageViewerCard({
    super.key,
    required this.message,
    required this.processing,
    required this.videoPreparing,
    required this.onRequestMediaPlayback,
    this.videoControllerInitializer,
  });

  final PipelineMessage? message;
  final bool processing;
  final bool videoPreparing;
  final Future<void> Function([int? messageId]) onRequestMediaPlayback;
  final VideoControllerInitializer? videoControllerInitializer;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildContent(context),
            ),
          ),
          if (processing)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final data = message;
    if (data == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 100),
          Icon(Icons.check_circle, color: Colors.green, size: 96),
          SizedBox(height: 16),
          Text('收藏夹已清空，干得漂亮！', style: TextStyle(fontSize: 18)),
        ],
      );
    }

    final preview = data.preview;
    final linkCard = preview.linkCard;
    final mediaItems = preview.mediaItems;
    if (preview.kind == MessagePreviewKind.photo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaGalleryPreview(
            items: mediaItems,
            preparing: videoPreparing,
            onRequestPlayback: onRequestMediaPlayback,
            controllerInitializer: videoControllerInitializer,
            fallbackImagePath: preview.localImagePath,
          ),
          const SizedBox(height: 12),
          _PreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 16,
          ),
        ],
      );
    }

    if (preview.kind == MessagePreviewKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaGalleryPreview(
            items: mediaItems,
            preparing: videoPreparing,
            onRequestPlayback: onRequestMediaPlayback,
            controllerInitializer: videoControllerInitializer,
            preferVideoFallback: true,
            fallbackVideoPath: preview.localVideoPath,
            fallbackThumbnailPath: preview.localVideoThumbnailPath,
          ),
          if (mediaItems.isEmpty) ...[
            const SizedBox(height: 12),
            _buildVideoMeta(context, preview.videoDurationSeconds),
            const SizedBox(height: 8),
          ] else
            const SizedBox(height: 12),
          _PreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 16,
          ),
        ],
      );
    }

    if (preview.kind == MessagePreviewKind.audio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AudioPreview(
            audioPath: preview.localAudioPath,
            preparing: videoPreparing,
            onRequestPlayback: onRequestMediaPlayback,
            tracks: preview.audioTracks,
          ),
          const SizedBox(height: 12),
          if (preview.subtitle != null && preview.subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                preview.subtitle!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          _buildVideoMeta(context, preview.audioDurationSeconds),
          const SizedBox(height: 8),
          Text(
            preview.title,
            style: TextStyle(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    if (linkCard != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LinkCard(link: linkCard),
          const SizedBox(height: 12),
          _PreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 18,
          ),
        ],
      );
    }

    return _PreviewText(
      text: preview.text,
      fallbackText: preview.title,
      fontSize: 18,
    );
  }

  Widget _buildVideoMeta(BuildContext context, int? durationSeconds) {
    if (durationSeconds == null) {
      return const SizedBox.shrink();
    }
    return Text(
      '时长 ${_formatDuration(durationSeconds)}',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _MediaGalleryPreview extends StatelessWidget {
  const _MediaGalleryPreview({
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
        return _VideoPreview(
          videoPath: fallbackVideoPath,
          thumbnailPath: fallbackThumbnailPath,
          preparing: preparing,
          onRequestPlayback: onRequestPlayback,
          controllerInitializer: controllerInitializer,
        );
      }
      return _buildPhoto(fallbackImagePath);
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
          _VideoPreview(
            videoPath: item.fullPath,
            thumbnailPath: item.previewPath,
            preparing: preparing,
            onRequestPlayback: ([messageId]) =>
                onRequestPlayback(item.messageId),
            controllerInitializer: controllerInitializer,
          ),
          if (item.durationSeconds != null) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) => Text(
                '时长 ${_formatDuration(item.durationSeconds!)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      );
    }
    return _buildPhoto(item.previewPath ?? item.fullPath);
  }

  Widget _buildPhoto(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return Container(
        width: double.infinity,
        height: 240,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('图片已识别（本地文件未就绪）'),
      );
    }

    return Image.file(
      io.File(imagePath),
      width: double.infinity,
      height: 240,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: double.infinity,
          height: 240,
          color: Colors.black12,
          alignment: Alignment.center,
          child: const Text('图片加载失败'),
        );
      },
    );
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link});

  final LinkCardPreview link;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(link.url);
          if (uri == null) {
            return;
          }
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (link.localImagePath != null && link.localImagePath!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    io.File(link.localImagePath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 72),
                  ),
                ),
              if (link.localImagePath != null && link.localImagePath!.isNotEmpty)
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (link.siteName.isNotEmpty)
                      Text(
                        link.siteName,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    if (link.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          link.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (link.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          link.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      link.displayUrl.isEmpty ? link.url : link.displayUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewText extends StatefulWidget {
  const _PreviewText({
    required this.text,
    required this.fallbackText,
    required this.fontSize,
  });

  final TdFormattedTextDto? text;
  final String fallbackText;
  final double fontSize;

  @override
  State<_PreviewText> createState() => _PreviewTextState();
}

class _PreviewTextState extends State<_PreviewText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final text = widget.text;
    if (text == null || text.entities.isEmpty) {
      return Text(
        widget.fallbackText,
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: _buildSpans(context, text),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, TdFormattedTextDto text) {
    final spans = <InlineSpan>[];
    final entities = [...text.entities]
      ..sort((a, b) => a.offset.compareTo(b.offset));
    var cursor = 0;
    for (final entity in entities) {
      if (entity.length <= 0 ||
          entity.offset < cursor ||
          entity.offset > text.text.length) {
        continue;
      }
      if (entity.offset > cursor) {
        spans.add(TextSpan(text: text.text.substring(cursor, entity.offset)));
      }
      final end = (entity.offset + entity.length).clamp(
        entity.offset,
        text.text.length,
      );
      final entityText = text.text.substring(entity.offset, end);
      spans.add(_buildEntitySpan(context, entity, entityText));
      cursor = end;
    }
    if (cursor < text.text.length) {
      spans.add(TextSpan(text: text.text.substring(cursor)));
    }
    return spans;
  }

  TextSpan _buildEntitySpan(
    BuildContext context,
    TdTextEntityDto entity,
    String entityText,
  ) {
    final link = _toLink(entity, entityText);
    if (link == null) {
      return TextSpan(text: entityText);
    }
    final recognizer = TapGestureRecognizer()
      ..onTap = () => _openLink(context, link);
    _recognizers.add(recognizer);
    return TextSpan(
      text: entityText,
      style: const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
      ),
      recognizer: recognizer,
    );
  }

  String? _toLink(TdTextEntityDto entity, String text) {
    if (entity.kind == TdTextEntityKind.textUrl) {
      return entity.url;
    }
    if (entity.kind == TdTextEntityKind.url) {
      return text;
    }
    if (entity.kind == TdTextEntityKind.emailAddress) {
      return 'mailto:$text';
    }
    if (entity.kind == TdTextEntityKind.phoneNumber) {
      return 'tel:$text';
    }
    return null;
  }

  Future<void> _openLink(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('链接打开失败')));
    }
  }

  void _disposeRecognizers() {
    for (final item in _recognizers) {
      item.dispose();
    }
    _recognizers.clear();
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({
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
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  static const Duration _initializeTimeout = Duration(seconds: 5);

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
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
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
      await initialize(next).timeout(_initializeTimeout);
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
      return _buildPlaceholder('视频加载中...');
    }
    final errorText = _errorText;
    if (errorText != null) {
      return _buildErrorState(errorText);
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
            height: 240,
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
      height: 240,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          _buildPlaceholder('视频缩略图加载失败'),
    );
  }

  Widget _buildPendingPreview({String? thumbnailPath}) {
    final body = thumbnailPath == null
        ? _buildPlaceholder(widget.preparing ? '视频下载中...' : '视频已识别（点击播放开始下载）')
        : Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnail(thumbnailPath),
              ColoredBox(color: Colors.black26),
            ],
          );
    return SizedBox(
      width: double.infinity,
      height: 240,
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

  Widget _buildPlaceholder(String text) {
    return Container(
      width: double.infinity,
      height: 240,
      color: Colors.black12,
      alignment: Alignment.center,
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildErrorState(String text) {
    return SizedBox(
      width: double.infinity,
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildPlaceholder(text),
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

class _AudioPreview extends StatefulWidget {
  const _AudioPreview({
    required this.audioPath,
    required this.preparing,
    required this.onRequestPlayback,
    required this.tracks,
  });

  final String? audioPath;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final List<AudioTrackPreview> tracks;

  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  AudioPlayer? _player;
  String? _currentPath;
  int? _currentTrackMessageId;
  bool _initializing = false;

  @override
  void didUpdateWidget(covariant _AudioPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath != widget.audioPath ||
        oldWidget.tracks != widget.tracks) {
      unawaited(_disposePlayer());
    }
  }

  @override
  void dispose() {
    unawaited(_disposePlayer());
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    _currentPath = null;
    _currentTrackMessageId = null;
    if (player != null) {
      await player.dispose();
    }
  }

  Future<void> _togglePlayback(AudioTrackPreview track) async {
    final path = track.localAudioPath;
    if (path == null || path.isEmpty || !io.File(path).existsSync()) {
      await widget.onRequestPlayback(track.messageId);
      return;
    }
    if (_player == null || _currentPath != path) {
      setState(() {
        _initializing = true;
      });
      await _disposePlayer();
      final player = AudioPlayer();
      try {
        await player.setFilePath(path);
        if (!mounted) {
          await player.dispose();
          return;
        }
        _player = player;
        _currentPath = path;
        _currentTrackMessageId = track.messageId;
      } finally {
        if (mounted) {
          setState(() {
            _initializing = false;
          });
        }
      }
    }
    final player = _player;
    if (player == null) {
      return;
    }
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = widget.tracks.isEmpty
        ? [
            AudioTrackPreview(
              messageId: 0,
              title: '音频',
              localAudioPath: widget.audioPath,
            ),
          ]
        : widget.tracks;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [for (final track in tracks) _buildTrackRow(context, track)],
      ),
    );
  }

  Widget _buildTrackRow(BuildContext context, AudioTrackPreview track) {
    final path = track.localAudioPath;
    final hasLocalFile =
        path != null && path.isNotEmpty && io.File(path).existsSync();
    final isPlaying =
        _player?.playing == true && _currentTrackMessageId == track.messageId;
    final label = _initializing && _currentTrackMessageId == track.messageId
        ? '音频加载中...'
        : hasLocalFile
        ? '点击播放音频'
        : widget.preparing && _currentTrackMessageId == track.messageId
        ? '音频下载中...'
        : '音频已识别（点击播放开始下载）';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: widget.preparing || _initializing
                ? null
                : () => _togglePlayback(track),
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (track.subtitle != null && track.subtitle!.isNotEmpty)
                  Text(
                    track.subtitle!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (track.audioDurationSeconds != null)
            Text(
              _formatDuration(track.audioDurationSeconds!),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
