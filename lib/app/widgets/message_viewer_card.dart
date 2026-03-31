import 'dart:io' as io;
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class MessageViewerCard extends StatelessWidget {
  const MessageViewerCard({
    super.key,
    required this.message,
    required this.processing,
  });

  final PipelineMessage? message;
  final bool processing;

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
              child: _buildContent(),
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

  Widget _buildContent() {
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
    if (preview.kind == MessagePreviewKind.photo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(preview.localImagePath),
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
          _VideoPreview(
            videoPath: preview.localVideoPath,
            thumbnailPath: preview.localVideoThumbnailPath,
          ),
          const SizedBox(height: 12),
          _buildVideoMeta(preview.videoDurationSeconds),
          const SizedBox(height: 8),
          _PreviewText(
            text: preview.text,
            fallbackText: preview.title,
            fontSize: 16,
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

  Widget _buildVideoMeta(int? durationSeconds) {
    if (durationSeconds == null) {
      return const SizedBox.shrink();
    }
    return Text(
      '时长 ${_formatDuration(durationSeconds)}',
      style: const TextStyle(color: Colors.black54),
    );
  }

  String _formatDuration(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = safe ~/ 60;
    final seconds = safe % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PreviewText extends StatefulWidget {
  const _PreviewText({
    required this.text,
    required this.fallbackText,
    required this.fontSize,
  });

  final FormattedText? text;
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
        style: TextStyle(fontSize: widget.fontSize, height: 1.4),
      );
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: widget.fontSize,
          height: 1.4,
          color: Colors.black87,
        ),
        children: _buildSpans(context, text),
      ),
    );
  }

  List<InlineSpan> _buildSpans(BuildContext context, FormattedText text) {
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
    TextEntity entity,
    String entityText,
  ) {
    final link = _toLink(entity.type, entityText);
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

  String? _toLink(TextEntityType type, String text) {
    if (type is TextEntityTypeTextUrl) {
      return type.url;
    }
    if (type is TextEntityTypeUrl) {
      return text;
    }
    if (type is TextEntityTypeEmailAddress) {
      return 'mailto:$text';
    }
    if (type is TextEntityTypePhoneNumber) {
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
  const _VideoPreview({required this.videoPath, required this.thumbnailPath});

  final String? videoPath;
  final String? thumbnailPath;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  String? _currentPath;
  bool _loading = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _syncController();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _syncController() async {
    final path = widget.videoPath;
    if (path == null || path.isEmpty || !io.File(path).existsSync()) {
      await _disposeController();
      _ensureRetryTimer(path);
      if (mounted) {
        setState(() {
          _currentPath = path;
          _loading = false;
        });
      }
      return;
    }

    if (_currentPath == path && _controller?.value.isInitialized == true) {
      _retryTimer?.cancel();
      return;
    }

    setState(() {
      _loading = true;
      _currentPath = path;
    });

    await _disposeController();
    final next = VideoPlayerController.file(io.File(path));
    try {
      await next.initialize();
      next.setLooping(true);
      if (!mounted) {
        await next.dispose();
        return;
      }
      setState(() {
        _controller = next;
        _loading = false;
      });
      _retryTimer?.cancel();
    } catch (_) {
      await next.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _controller = null;
        _loading = false;
      });
      _ensureRetryTimer(path);
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
      unawaited(_syncController());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildPlaceholder('视频加载中...');
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      final thumb = widget.thumbnailPath;
      if (thumb != null && thumb.isNotEmpty) {
        return _buildThumbnail(thumb);
      }
      return _buildPlaceholder('视频已识别（本地文件未就绪）');
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

  Widget _buildPlaceholder(String text) {
    return Container(
      width: double.infinity,
      height: 240,
      color: Colors.black12,
      alignment: Alignment.center,
      child: Text(text),
    );
  }
}
