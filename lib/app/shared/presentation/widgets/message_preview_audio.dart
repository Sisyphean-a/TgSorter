import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_actions.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

typedef AudioPreviewControllerFactory = AudioPreviewController Function();

abstract interface class AudioPreviewController {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  bool get playing;
  double get speed;

  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class JustAudioPreviewController implements AudioPreviewController {
  JustAudioPreviewController() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  bool get playing => _player.playing;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  double get speed => _player.speed;

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
}

class MessagePreviewAudio extends StatefulWidget {
  const MessagePreviewAudio({
    super.key,
    required this.audioPath,
    required this.preparing,
    required this.onRequestPlayback,
    required this.tracks,
    this.isPreparingTrack,
    this.controllerFactory = _defaultAudioPreviewControllerFactory,
    this.fileActions = const PlatformFileActions(),
  });

  final String? audioPath;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final List<AudioTrackPreview> tracks;
  final bool Function(int? messageId)? isPreparingTrack;
  final AudioPreviewControllerFactory controllerFactory;
  final PlatformFileActions fileActions;

  static AudioPreviewController _defaultAudioPreviewControllerFactory() {
    return JustAudioPreviewController();
  }

  @override
  State<MessagePreviewAudio> createState() => _MessagePreviewAudioState();
}

class _MessagePreviewAudioState extends State<MessagePreviewAudio> {
  AudioPreviewController? _controller;
  String? _currentPath;
  int? _currentTrackMessageId;
  bool _initializing = false;
  Duration _position = Duration.zero;
  Duration? _duration;
  double _speed = 1.0;
  String? _errorText;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

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
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription = null;
    final controller = _controller;
    _controller = null;
    _currentPath = null;
    _currentTrackMessageId = null;
    _position = Duration.zero;
    _duration = null;
    _speed = 1.0;
    _errorText = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  AudioPreviewController _ensureController() {
    final current = _controller;
    if (current != null) {
      return current;
    }
    final next = widget.controllerFactory();
    _positionSubscription = next.positionStream.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = value;
      });
    });
    _durationSubscription = next.durationStream.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = value;
      });
    });
    _controller = next;
    _speed = next.speed;
    return next;
  }

  AudioTrackPreview? _findTrackById(int? messageId) {
    if (messageId == null) {
      return null;
    }
    for (final track in _effectiveTracks) {
      if (track.messageId == messageId) {
        return track;
      }
    }
    return null;
  }

  List<AudioTrackPreview> get _effectiveTracks {
    return widget.tracks.isEmpty
        ? [
            AudioTrackPreview(
              messageId: 0,
              title: '音频',
              localAudioPath: widget.audioPath,
            ),
          ]
        : widget.tracks;
  }

  Future<void> _togglePlayback(AudioTrackPreview track) async {
    final path = track.localAudioPath;
    if (path == null || path.isEmpty || !io.File(path).existsSync()) {
      if (mounted) {
        setState(() {
          _currentTrackMessageId = track.messageId;
        });
      }
      await widget.onRequestPlayback(track.messageId);
      return;
    }
    final controller = _ensureController();
    final switchingTrack = _currentPath != path;
    if (switchingTrack) {
      setState(() {
        _initializing = true;
        _currentTrackMessageId = track.messageId;
        _errorText = null;
      });
      try {
        await controller.setFilePath(path);
        _currentPath = path;
        _position = Duration.zero;
        _duration = track.audioDurationSeconds == null
            ? null
            : Duration(seconds: track.audioDurationSeconds!);
        _speed = controller.speed;
      } catch (error, stackTrace) {
        developer.log(
          'audio setFilePath failed path=$path',
          name: 'AudioPreview',
          error: error,
          stackTrace: stackTrace,
        );
        if (mounted) {
          setState(() {
            _errorText = '音频加载失败：$error';
          });
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _initializing = false;
          });
        }
      }
    }
    final activeController = _controller;
    if (activeController == null) {
      return;
    }
    if (_currentTrackMessageId != track.messageId) {
      _currentTrackMessageId = track.messageId;
    }
    if (activeController.playing && !switchingTrack) {
      await activeController.pause();
      if (mounted) {
        setState(() {
          _errorText = null;
        });
      }
    } else {
      unawaited(
        activeController.play().catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'audio play failed path=$path',
            name: 'AudioPreview',
            error: error,
            stackTrace: stackTrace,
          );
          if (!mounted) {
            return;
          }
          setState(() {
            _errorText = '音频播放失败：$error';
          });
        }),
      );
      if (mounted) {
        setState(() {
          _errorText = null;
        });
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _seekTo(Duration target) async {
    final controller = _controller;
    final duration = _resolvedDuration;
    if (controller == null || duration <= Duration.zero) {
      return;
    }
    final clamped = clampVideoSeekTarget(target: target, duration: duration);
    await controller.seek(clamped);
    if (mounted) {
      setState(() {
        _position = clamped;
      });
    }
  }

  Future<void> _setSpeed(double speed) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    await controller.setSpeed(speed);
    if (mounted) {
      setState(() {
        _speed = speed;
      });
    }
  }

  AudioTrackPreview? get _selectedTrack {
    return _findTrackById(_currentTrackMessageId) ??
        _effectiveTracks.firstOrNull;
  }

  Duration get _resolvedDuration {
    final trackDuration = _selectedTrack?.audioDurationSeconds;
    return _duration ??
        (trackDuration == null
            ? Duration.zero
            : Duration(seconds: trackDuration));
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _effectiveTracks;
    return MessageMediaShell(
      key: const Key('message-preview-audio-tracks'),
      moreActions: _buildMoreActions(_selectedTrack),
      footer: _buildFooter(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final track in tracks) _buildTrackRow(context, track)],
      ),
    );
  }

  List<MessageMediaAction> _buildMoreActions(AudioTrackPreview? track) {
    final path = track?.localAudioPath;
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

  Widget _buildTrackRow(BuildContext context, AudioTrackPreview track) {
    final path = track.localAudioPath;
    final hasLocalFile =
        path != null && path.isNotEmpty && io.File(path).existsSync();
    final isCurrentTrack = _currentTrackMessageId == track.messageId;
    final trackPreparing =
        widget.isPreparingTrack?.call(track.messageId) ??
        (widget.preparing && isCurrentTrack);
    final isPlaying = _controller?.playing == true && isCurrentTrack;
    final label = _errorText != null && isCurrentTrack
        ? _errorText!
        : _initializing && _currentTrackMessageId == track.messageId
        ? '音频加载中...'
        : hasLocalFile && isCurrentTrack && isPlaying
        ? '播放中'
        : hasLocalFile && isCurrentTrack
        ? '已暂停，可调整进度和倍速'
        : hasLocalFile
        ? '点击播放音频'
        : trackPreparing
        ? '音频下载中...'
        : '音频已识别（点击播放开始下载）';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton.filled(
            onPressed: trackPreparing || _initializing
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
          if (isCurrentTrack && _resolvedDuration > Duration.zero)
            PreviewMetaText(
              text:
                  '${formatPreviewDuration(_position.inSeconds)} / ${formatPreviewDuration(_resolvedDuration.inSeconds)}',
            )
          else if (track.audioDurationSeconds != null)
            PreviewMetaText(
              text: formatPreviewDuration(track.audioDurationSeconds!),
            ),
        ],
      ),
    );
  }

  Widget? _buildFooter(BuildContext context) {
    final selectedTrack = _selectedTrack;
    final duration = _resolvedDuration;
    final hasDuration = duration > Duration.zero;
    if (selectedTrack == null || _currentTrackMessageId == null) {
      return null;
    }
    final safePosition = hasDuration
        ? clampVideoSeekTarget(target: _position, duration: duration)
        : Duration.zero;
    final maxMilliseconds = hasDuration
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                value: hasDuration
                    ? safePosition.inMilliseconds.toDouble().clamp(
                        0.0,
                        maxMilliseconds,
                      )
                    : 0.0,
                min: 0,
                max: maxMilliseconds,
                onChanged: hasDuration
                    ? (value) {
                        unawaited(
                          _seekTo(Duration(milliseconds: value.round())),
                        );
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<double>(
              key: const Key('message-preview-audio-speed-menu'),
              tooltip: '播放速度',
              initialValue: _speed,
              onSelected: _setSpeed,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 0.5, child: Text('0.5x')),
                PopupMenuItem(value: 1.0, child: Text('1.0x')),
                PopupMenuItem(value: 1.5, child: Text('1.5x')),
                PopupMenuItem(value: 2.0, child: Text('2.0x')),
              ],
              child: _AudioFooterChip(
                label:
                    '${_speed.toStringAsFixed(_speed == _speed.roundToDouble() ? 0 : 1)}x',
              ),
            ),
          ],
        ),
        Text(
          '${formatPreviewDuration(safePosition.inSeconds)} / ${formatPreviewDuration(duration.inSeconds)}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _AudioFooterChip extends StatelessWidget {
  const _AudioFooterChip({required this.label});

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
