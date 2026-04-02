import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/widgets/message_preview_helpers.dart';

class MessagePreviewAudio extends StatefulWidget {
  const MessagePreviewAudio({
    super.key,
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
  State<MessagePreviewAudio> createState() => _MessagePreviewAudioState();
}

class _MessagePreviewAudioState extends State<MessagePreviewAudio> {
  AudioPlayer? _player;
  String? _currentPath;
  int? _currentTrackMessageId;
  bool _initializing = false;

  @override
  void didUpdateWidget(covariant MessagePreviewAudio oldWidget) {
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
      key: const Key('message-preview-audio-tracks'),
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
            PreviewMetaText(
              text: formatPreviewDuration(track.audioDurationSeconds!),
            ),
        ],
      ),
    );
  }
}
