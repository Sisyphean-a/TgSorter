import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:video_player/video_player.dart';

class MessagePreviewVideoFullscreen extends StatefulWidget {
  const MessagePreviewVideoFullscreen({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onSeekBy,
    required this.onTogglePlayback,
    required this.onToggleLooping,
    required this.onSetPlaybackSpeed,
    required this.onSetVolume,
    required this.currentSpeed,
    required this.currentVolume,
    required this.looping,
    required this.trailingActions,
  });

  final VideoPlayerController controller;
  final VoidCallback onClose;
  final Future<void> Function(int seconds) onSeekBy;
  final VoidCallback onTogglePlayback;
  final VoidCallback onToggleLooping;
  final Future<void> Function(double speed) onSetPlaybackSpeed;
  final Future<void> Function(double volume) onSetVolume;
  final double currentSpeed;
  final double currentVolume;
  final bool looping;
  final List<Widget> trailingActions;

  @override
  State<MessagePreviewVideoFullscreen> createState() =>
      _MessagePreviewVideoFullscreenState();
}

class _MessagePreviewVideoFullscreenState
    extends State<MessagePreviewVideoFullscreen> {
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTick);
    _armHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_handleTick);
    super.dispose();
  }

  void _handleTick() {
    if (mounted) {
      setState(() {});
    }
  }

  void _armHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _controlsVisible = false;
      });
    });
  }

  void _toggleOverlay() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _armHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final duration = value.duration;
    final position = clampVideoSeekTarget(
      target: value.position,
      duration: duration,
    );
    final maxValue = duration > Duration.zero
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final sliderValue = duration > Duration.zero
        ? position.inMilliseconds.toDouble().clamp(0.0, maxValue)
        : 0.0;
    return Material(
      color: Colors.black,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleOverlay,
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            if (_controlsVisible)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Colors.transparent, Color(0x99000000)],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: widget.onClose,
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              ...widget.trailingActions,
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton.filled(
                                onPressed: () => widget.onSeekBy(-10),
                                icon: const Icon(Icons.replay_10_rounded),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filled(
                                onPressed: widget.onTogglePlayback,
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filled(
                                onPressed: () => widget.onSeekBy(10),
                                icon: const Icon(Icons.forward_10_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text(
                                formatPreviewDuration(position.inSeconds),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Expanded(
                                child: Slider(
                                  value: sliderValue,
                                  min: 0,
                                  max: maxValue,
                                  onChanged: duration > Duration.zero
                                      ? (nextValue) {
                                          widget.controller.seekTo(
                                            Duration(
                                              milliseconds: nextValue.round(),
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              ),
                              Text(
                                formatPreviewDuration(duration.inSeconds),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PopupMenuButton<double>(
                                tooltip: '播放速度',
                                initialValue: widget.currentSpeed,
                                onSelected: widget.onSetPlaybackSpeed,
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 0.5, child: Text('0.5x')),
                                  PopupMenuItem(value: 1.0, child: Text('1.0x')),
                                  PopupMenuItem(value: 1.5, child: Text('1.5x')),
                                  PopupMenuItem(value: 2.0, child: Text('2.0x')),
                                ],
                                child: _FullscreenChip(
                                  label: '${widget.currentSpeed.toStringAsFixed(widget.currentSpeed == widget.currentSpeed.roundToDouble() ? 0 : 1)}x',
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<double>(
                                tooltip: '音量',
                                initialValue: widget.currentVolume,
                                onSelected: widget.onSetVolume,
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 0.0, child: Text('静音')),
                                  PopupMenuItem(value: 0.3, child: Text('30%')),
                                  PopupMenuItem(value: 0.6, child: Text('60%')),
                                  PopupMenuItem(value: 1.0, child: Text('100%')),
                                ],
                                child: _FullscreenChip(
                                  label: widget.currentVolume == 0
                                      ? '静音'
                                      : '音量 ${(widget.currentVolume * 100).round()}%',
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text('循环'),
                                selected: widget.looping,
                                onSelected: (_) => widget.onToggleLooping(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenChip extends StatelessWidget {
  const _FullscreenChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
