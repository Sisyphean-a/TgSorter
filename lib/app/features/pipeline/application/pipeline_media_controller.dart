import 'dart:async';

import 'package:get/get.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

import 'pipeline_media_refresh_service.dart';
import 'pipeline_prepared_message_merger.dart';
import 'pipeline_media_session_controller.dart';
import 'pipeline_runtime_state.dart';

class PipelineMediaController implements PipelineLegacyMediaController {
  PipelineMediaController({
    required PipelineRuntimeState state,
    required PipelineMediaRefreshService mediaRefresh,
    PipelineSettingsReader? settingsReader,
    Future<void> Function(ClassifyOperationLog log)? appendLog,
    String Function(String prefix, int messageId)? logIdBuilder,
    int Function()? nowMs,
    void Function(Object error)? reportGeneralError,
    Duration videoRefreshInterval = const Duration(seconds: 1),
  }) : _state = state,
       _mediaRefresh = mediaRefresh,
       _settingsReader =
           settingsReader ?? _StaticPipelineSettingsReader.forMediaRetries(),
       _appendLog = appendLog,
       _logIdBuilder = logIdBuilder ?? _defaultLogIdBuilder,
       _nowMs = nowMs ?? _defaultNowMs,
       _reportGeneralError = reportGeneralError,
       _videoRefreshInterval = videoRefreshInterval;

  final PipelineRuntimeState _state;
  final PipelineMediaRefreshService _mediaRefresh;
  final PipelineSettingsReader _settingsReader;
  final Future<void> Function(ClassifyOperationLog log)? _appendLog;
  final String Function(String prefix, int messageId) _logIdBuilder;
  final int Function() _nowMs;
  final void Function(Object error)? _reportGeneralError;
  final Duration _videoRefreshInterval;
  Timer? _videoRefreshTimer;
  int? _refreshTargetMessageId;
  int _refreshCycle = 0;
  final Map<int, Timer> _mediaRetryTimers = <int, Timer>{};

  @override
  bool isPreparingMessageId(int? messageId) {
    if (messageId == null) {
      return _state.videoPreparing.value;
    }
    return _state.preparingMessageIds.contains(messageId);
  }

  @override
  Future<void> prepareCurrentMedia([int? targetMessageId]) async {
    final message = _state.currentMessage.value;
    if (message == null ||
        (message.preview.kind != MessagePreviewKind.video &&
            message.preview.kind != MessagePreviewKind.audio &&
            message.preview.kind != MessagePreviewKind.photo) ||
        _state.videoPreparing.value) {
      return;
    }
    final requestedMessageId = targetMessageId ?? message.id;
    _cancelMediaRetry(requestedMessageId);
    _state.mediaRetryAttempts.remove(requestedMessageId);
    _refreshTargetMessageId = requestedMessageId;
    _state.preparingMessageIds
      ..clear()
      ..add(requestedMessageId);
    _state.videoPreparing.value = true;
    _state.mediaFailureMessages.remove(requestedMessageId);
    try {
      if (message.preview.kind == MessagePreviewKind.photo) {
        await refreshCurrentMediaIfNeeded();
        return;
      }
      final prepared = await _mediaRefresh.prepareCurrentMedia(
        sourceChatId: message.sourceChatId,
        messageId: requestedMessageId,
      );
      final base = _messageById(prepared.id) ?? message;
      final merged = mergePreparedMessage(base, prepared);
      _replaceMessage(merged);
      await _handleMediaSuccess(requestedMessageId);
      if (!_currentMessageContainsTarget()) {
        stop();
        return;
      }
      await refreshCurrentMediaIfNeeded();
    } catch (error) {
      stop();
      await _handleMediaFailure(requestedMessageId, error);
    }
  }

  @override
  Future<void> refreshCurrentMediaIfNeeded() async {
    final message = _state.currentMessage.value;
    if (message == null || !_needsMediaRefresh(message.preview)) {
      _state.preparingMessageIds.clear();
      _state.videoPreparing.value = false;
      _refreshTargetMessageId = null;
      return;
    }
    final previewWarmupMessageId = _nextPreviewWarmupMessageId(message);
    if (previewWarmupMessageId != null) {
      try {
        await _mediaRefresh.prepareCurrentPreview(
          sourceChatId: message.sourceChatId,
          messageId: previewWarmupMessageId,
        );
      } catch (error) {
        await _handleMediaFailure(previewWarmupMessageId, error);
        stop();
        return;
      }
    }
    _syncPreparingState(message.preview);
    _videoRefreshTimer?.cancel();
    final refreshCycle = ++_refreshCycle;
    _videoRefreshTimer = Timer.periodic(_videoRefreshInterval, (_) async {
      if (refreshCycle != _refreshCycle) {
        return;
      }
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
        await _handleMediaSuccess(refreshMessageId);
        _syncPreparingState(merged.preview);
        if (!_needsMediaRefresh(merged.preview)) {
          stop();
        }
      } catch (error) {
        final currentTarget = _state.currentMessage.value == null
            ? _refreshTargetMessageId
            : _nextRefreshMessageId(_state.currentMessage.value!);
        stop();
        await _handleMediaFailure(currentTarget, error);
      }
    });
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

  @override
  void stop() {
    _refreshCycle++;
    _videoRefreshTimer?.cancel();
    _videoRefreshTimer = null;
    _refreshTargetMessageId = null;
    _state.preparingMessageIds.clear();
    _state.videoPreparing.value = false;
  }

  Future<void> _handleMediaSuccess(int messageId) async {
    final hadRetries = (_state.mediaRetryAttempts.remove(messageId) ?? 0) > 0;
    _cancelMediaRetry(messageId);
    _state.mediaFailureMessages.remove(messageId);
    if (!hadRetries) {
      return;
    }
    await _appendMediaLog(
      messageId: messageId,
      status: ClassifyOperationStatus.mediaRetrySuccess,
    );
  }

  Future<void> _handleMediaFailure(int? messageId, Object error) async {
    _recordFailure(messageId, error);
    if (messageId == null) {
      _reportGeneralError?.call(error);
      return;
    }
    final attempt = (_state.mediaRetryAttempts[messageId] ?? 0) + 1;
    _state.mediaRetryAttempts[messageId] = attempt;
    final retryLimit = _settingsReader.currentSettings.mediaRetryLimit;
    final canRetry = attempt <= retryLimit;
    final status = attempt == 1
        ? ClassifyOperationStatus.mediaFailed
        : ClassifyOperationStatus.mediaRetryFailed;
    await _appendMediaLog(
      messageId: messageId,
      status: status,
      reason: _mediaFailureReason(
        error: error,
        attempt: attempt,
        canRetry: canRetry,
      ),
    );
    if (canRetry) {
      _scheduleMediaRetry(messageId);
      return;
    }
    _state.mediaRetryAttempts.remove(messageId);
    _cancelMediaRetry(messageId);
    _reportGeneralError?.call(error);
  }

  bool _needsMediaRefresh(MessagePreview preview) {
    if (preview.mediaItems.isNotEmpty) {
      return preview.mediaItems.any((item) {
        if (!_hasPath(item.previewPath) && !_hasPath(item.fullPath)) {
          return true;
        }
        final waitingForPlayback =
            preview.kind == MessagePreviewKind.video &&
            _state.videoPreparing.value &&
            (_refreshTargetMessageId == null ||
                _refreshTargetMessageId == item.messageId);
        return item.kind == MediaItemKind.video &&
            waitingForPlayback &&
            !_hasPath(item.fullPath);
      });
    }
    if (preview.kind == MessagePreviewKind.video) {
      return !_hasPath(preview.localVideoThumbnailPath) ||
          (_state.videoPreparing.value && !_hasPath(preview.localVideoPath));
    }
    if (preview.kind == MessagePreviewKind.photo) {
      return !_hasPath(preview.localImagePath);
    }
    if (preview.kind == MessagePreviewKind.audio) {
      return _state.videoPreparing.value && !_hasReadyAudioPath(preview);
    }
    return false;
  }

  int? _nextPreviewWarmupMessageId(PipelineMessage current) {
    final preview = current.preview;
    if (preview.kind == MessagePreviewKind.photo) {
      return _nextRefreshMessageId(current);
    }
    if (preview.kind == MessagePreviewKind.video &&
        !_hasVideoPreview(preview)) {
      return _nextRefreshMessageId(current);
    }
    return null;
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
          !_hasReadyAudioPath(preview) && _state.videoPreparing.value;
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

  bool _hasVideoPreview(MessagePreview preview) {
    if (preview.mediaItems.isNotEmpty) {
      return preview.mediaItems.any((item) {
        return item.kind == MediaItemKind.video &&
            (_hasPath(item.previewPath) || _hasPath(item.fullPath));
      });
    }
    return _hasPath(preview.localVideoThumbnailPath) ||
        _hasPath(preview.localVideoPath);
  }

  bool _hasReadyAudioPath(MessagePreview preview) {
    final targetId = _refreshTargetMessageId;
    if (preview.audioTracks.isEmpty || targetId == null) {
      return _hasPath(preview.localAudioPath);
    }
    for (final track in preview.audioTracks) {
      if (track.messageId == targetId) {
        return _hasPath(track.localAudioPath);
      }
    }
    return _hasPath(preview.localAudioPath);
  }

  void _recordFailure(int? messageId, Object error) {
    if (messageId == null) {
      return;
    }
    _state.mediaFailureMessages[messageId] = '媒体加载失败：$error';
  }

  void _scheduleMediaRetry(int messageId) {
    _cancelMediaRetry(messageId);
    final delay = Duration(
      milliseconds: _settingsReader.currentSettings.mediaRetryDelayMs,
    );
    _mediaRetryTimers[messageId] = Timer(delay, () async {
      _mediaRetryTimers.remove(messageId);
      final current = _state.currentMessage.value;
      if (current == null || !_messageContains(current, messageId)) {
        _state.mediaRetryAttempts.remove(messageId);
        return;
      }
      _refreshTargetMessageId = messageId;
      _state.preparingMessageIds
        ..clear()
        ..add(messageId);
      _state.videoPreparing.value = true;
      await refreshCurrentMediaIfNeeded();
    });
  }

  void _cancelMediaRetry(int messageId) {
    _mediaRetryTimers.remove(messageId)?.cancel();
  }

  bool _messageContains(PipelineMessage message, int messageId) {
    return message.id == messageId || message.messageIds.contains(messageId);
  }

  Future<void> _appendMediaLog({
    required int messageId,
    required ClassifyOperationStatus status,
    String? reason,
  }) async {
    final append = _appendLog;
    if (append == null) {
      return;
    }
    await append(
      ClassifyOperationLog(
        id: _logIdBuilder('media', messageId),
        categoryKey: 'media',
        messageId: messageId,
        targetChatId: 0,
        createdAtMs: _nowMs(),
        status: status,
        reason: reason,
      ),
    );
  }

  String _mediaFailureReason({
    required Object error,
    required int attempt,
    required bool canRetry,
  }) {
    final delayMs = _settingsReader.currentSettings.mediaRetryDelayMs;
    if (canRetry) {
      return '第 $attempt 次失败，${delayMs}ms 后自动重试：$error';
    }
    return '自动重试已耗尽：$error';
  }

  static String _defaultLogIdBuilder(String prefix, int messageId) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$prefix-$messageId-$now';
  }

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;
}

class _StaticPipelineSettingsReader implements PipelineSettingsReader {
  _StaticPipelineSettingsReader(this.settingsStream);

  factory _StaticPipelineSettingsReader.forMediaRetries() {
    return _StaticPipelineSettingsReader(
      const AppSettings(
        categories: <CategoryConfig>[],
        sourceChatId: null,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 5,
        throttleMs: 1200,
        proxy: ProxySettings.empty,
        mediaRetryLimit: 0,
        mediaRetryDelayMs: 0,
      ).obs,
    );
  }

  @override
  final Rx<AppSettings> settingsStream;

  @override
  AppSettings get currentSettings => settingsStream.value;

  @override
  CategoryConfig getCategory(String key) {
    throw UnimplementedError();
  }
}
