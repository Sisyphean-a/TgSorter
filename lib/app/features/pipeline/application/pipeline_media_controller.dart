import 'dart:async';

import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

import 'pipeline_media_refresh_service.dart';
import 'pipeline_media_session_controller.dart';
import 'pipeline_runtime_state.dart';

class PipelineMediaController implements PipelineLegacyMediaController {
  PipelineMediaController({
    required PipelineRuntimeState state,
    required PipelineMediaRefreshService mediaRefresh,
    void Function(Object error)? reportGeneralError,
    Duration videoRefreshInterval = const Duration(seconds: 1),
  }) : _state = state,
       _mediaRefresh = mediaRefresh,
       _reportGeneralError = reportGeneralError,
       _videoRefreshInterval = videoRefreshInterval;

  final PipelineRuntimeState _state;
  final PipelineMediaRefreshService _mediaRefresh;
  final void Function(Object error)? _reportGeneralError;
  final Duration _videoRefreshInterval;
  Timer? _videoRefreshTimer;
  int? _refreshTargetMessageId;

  bool isPreparingMessageId(int? messageId) {
    if (messageId == null) {
      return _state.videoPreparing.value;
    }
    return _state.preparingMessageIds.contains(messageId);
  }

  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    final message = _state.currentMessage.value;
    if (message == null ||
        (message.preview.kind != MessagePreviewKind.video &&
            message.preview.kind != MessagePreviewKind.audio) ||
        _state.videoPreparing.value) {
      return;
    }
    final requestedMessageId = targetMessageId ?? message.id;
    _refreshTargetMessageId = requestedMessageId;
    _state.preparingMessageIds
      ..clear()
      ..add(requestedMessageId);
    _state.videoPreparing.value = true;
    try {
      final prepared = await _mediaRefresh.prepareCurrentMedia(
        sourceChatId: message.sourceChatId,
        messageId: requestedMessageId,
      );
      final base = _messageById(prepared.id) ?? message;
      final merged = mergePreparedMessage(base, prepared);
      _replaceMessage(merged);
      if (!_currentMessageContainsTarget()) {
        stop();
        return;
      }
      await refreshCurrentMediaIfNeeded();
    } catch (error) {
      _reportGeneralError?.call(error);
      stop();
    }
  }

  Future<void> refreshCurrentMediaIfNeeded() async {
    final message = _state.currentMessage.value;
    if (message == null || !_needsMediaRefresh(message.preview)) {
      _state.videoPreparing.value = false;
      _refreshTargetMessageId = null;
      return;
    }
    _syncPreparingState(message.preview);
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = Timer.periodic(_videoRefreshInterval, (_) async {
      try {
        final current = _state.currentMessage.value;
        if (current == null ||
            !_currentMessageContainsTarget() ||
            !_needsMediaRefresh(current.preview)) {
          stop();
          return;
        }
        final refreshMessageId = _nextRefreshMessageId(current) ?? current.id;
        final refreshed = await _mediaRefresh.refreshCurrentMedia(
          sourceChatId: current.sourceChatId,
          messageId: refreshMessageId,
        );
        final base = _messageById(refreshed.id) ?? current;
        final merged = mergePreparedMessage(base, refreshed);
        _replaceMessage(merged);
        _syncPreparingState(merged.preview);
        if (!_needsMediaRefresh(merged.preview)) {
          stop();
        }
      } catch (error) {
        _reportGeneralError?.call(error);
        stop();
      }
    });
  }

  PipelineMessage mergePreparedMessage(
    PipelineMessage current,
    PipelineMessage prepared,
  ) {
    if (current.preview.mediaItems.isNotEmpty) {
      final preparedItem = prepared.preview.mediaItems.isEmpty
          ? null
          : prepared.preview.mediaItems.first;
      if (preparedItem != null) {
        final items = current.preview.mediaItems
            .map((item) {
              if (item.messageId != prepared.id) {
                return item;
              }
              return item.copyWith(
                previewPath: preparedItem.previewPath,
                fullPath: preparedItem.fullPath,
                durationSeconds: preparedItem.durationSeconds,
                caption: preparedItem.caption,
              );
            })
            .toList(growable: false);
        final preview = current.preview.copyWith(
          mediaItems: items,
          localVideoPath:
              current.preview.localVideoPath ?? prepared.preview.localVideoPath,
          localVideoThumbnailPath:
              current.preview.localVideoThumbnailPath ??
              prepared.preview.localVideoThumbnailPath,
          localImagePath:
              current.preview.localImagePath ?? prepared.preview.localImagePath,
        );
        return current.copyWith(preview: preview);
      }
    }
    if (current.preview.kind != MessagePreviewKind.audio ||
        current.preview.audioTracks.length <= 1) {
      return prepared;
    }
    final tracks = current.preview.audioTracks
        .map((track) {
          if (track.messageId != prepared.id) {
            return track;
          }
          final preview = prepared.preview;
          return track.copyWith(
            localAudioPath: preview.localAudioPath,
            audioDurationSeconds: preview.audioDurationSeconds,
            title: preview.title,
            subtitle: preview.subtitle,
          );
        })
        .toList(growable: false);
    return current.copyWith(
      preview: current.preview.copyWith(audioTracks: tracks),
    );
  }

  PipelineMessage? _messageById(int messageId) {
    final current = _state.currentMessage.value;
    if (current?.id == messageId) {
      return current;
    }
    for (final item in _state.cache) {
      if (item.id == messageId) {
        return item;
      }
    }
    return null;
  }

  void _replaceMessage(PipelineMessage message) {
    for (var index = 0; index < _state.cache.length; index++) {
      if (_state.cache[index].id == message.id) {
        _state.cache[index] = message;
        break;
      }
    }
    if (_state.currentMessage.value?.id == message.id) {
      _state.currentMessage.value = message;
    }
  }

  bool _currentMessageContainsTarget() {
    final current = _state.currentMessage.value;
    if (current == null) {
      return false;
    }
    final targetId = _refreshTargetMessageId;
    if (targetId == null) {
      return true;
    }
    if (current.id == targetId) {
      return true;
    }
    return current.messageIds.contains(targetId);
  }

  void stop() {
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = null;
    _refreshTargetMessageId = null;
    _state.preparingMessageIds.clear();
    _state.videoPreparing.value = false;
  }

  bool _needsMediaRefresh(MessagePreview preview) {
    if (preview.kind == MessagePreviewKind.video) {
      if (preview.mediaItems.isNotEmpty) {
        return preview.mediaItems.any((item) {
          if (!_hasPath(item.previewPath)) {
            return true;
          }
          final waitingForPlayback =
              _state.videoPreparing.value &&
              (_refreshTargetMessageId == null ||
                  _refreshTargetMessageId == item.messageId);
          return item.kind == MediaItemKind.video &&
              waitingForPlayback &&
              !_hasPath(item.fullPath);
        });
      }
      return !_hasPath(preview.localVideoThumbnailPath) ||
          (_state.videoPreparing.value && !_hasPath(preview.localVideoPath));
    }
    if (preview.kind == MessagePreviewKind.audio) {
      return _state.videoPreparing.value && !_hasPath(preview.localAudioPath);
    }
    return false;
  }

  void _syncPreparingState(MessagePreview preview) {
    final targetId = _refreshTargetMessageId;
    if (preview.kind == MessagePreviewKind.video) {
      if (preview.mediaItems.isNotEmpty && targetId != null) {
        final waiting = preview.mediaItems.any((item) {
          if (item.kind != MediaItemKind.video) {
            return false;
          }
          if (item.messageId != targetId) {
            return false;
          }
          return !_hasPath(item.fullPath);
        });
        _state.videoPreparing.value = waiting && _state.videoPreparing.value;
        if (!waiting) {
          _state.preparingMessageIds.remove(targetId);
        }
        return;
      }
      _state.videoPreparing.value =
          !_hasPath(preview.localVideoPath) && _state.videoPreparing.value;
      return;
    }
    if (preview.kind == MessagePreviewKind.audio) {
      _state.videoPreparing.value =
          !_hasPath(preview.localAudioPath) && _state.videoPreparing.value;
      if (!_state.videoPreparing.value && targetId != null) {
        _state.preparingMessageIds.remove(targetId);
      }
      return;
    }
    _state.videoPreparing.value = false;
  }

  int? _nextRefreshMessageId(PipelineMessage current) {
    final targetId = _refreshTargetMessageId;
    if (targetId != null) {
      return targetId;
    }
    final preview = current.preview;
    if (preview.kind != MessagePreviewKind.video ||
        preview.mediaItems.isEmpty) {
      return current.id;
    }
    for (final item in preview.mediaItems) {
      if (!_hasPath(item.previewPath) && !_hasPath(item.fullPath)) {
        return item.messageId;
      }
    }
    return current.id;
  }

  bool _hasPath(String? path) {
    return path != null && path.isNotEmpty;
  }
}
