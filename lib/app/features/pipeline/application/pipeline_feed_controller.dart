import 'dart:async';
import 'dart:math' as math;

import 'package:tgsorter/app/models/pipeline_message.dart';

import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'remaining_count_service.dart';

class PipelineFeedController {
  static const int messagePageSize = 20;

  PipelineFeedController({
    required PipelineRuntimeState state,
    required PipelineNavigationService navigation,
    required MessageReadGateway messages,
    required MediaGateway media,
    required PipelineSettingsReader settings,
    required RemainingCountService remainingCount,
    required void Function(Object error) reportGeneralError,
    Future<void> Function()? refreshCurrentMediaIfNeeded,
  }) : _state = state,
       _navigation = navigation,
       _messages = messages,
       _media = media,
       _settings = settings,
       _remainingCount = remainingCount,
       _reportGeneralError = reportGeneralError,
       _refreshCurrentMediaIfNeeded = refreshCurrentMediaIfNeeded;

  final PipelineRuntimeState _state;
  final PipelineNavigationService _navigation;
  final MessageReadGateway _messages;
  final MediaGateway _media;
  final PipelineSettingsReader _settings;
  final RemainingCountService _remainingCount;
  final void Function(Object error) _reportGeneralError;
  final Future<void> Function()? _refreshCurrentMediaIfNeeded;

  int? tailMessageId;
  final Set<int> _previewPreparedMessageIds = <int>{};

  int get _currentIndex => _state.currentIndex;
  List<PipelineMessage> get _messageCache => _state.cache;

  Future<void> loadInitialMessages() async {
    unawaited(refreshRemainingCount());
    _navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    tailMessageId = null;
    final page = await _messages.fetchMessagePage(
      direction: _settings.currentSettings.fetchDirection,
      sourceChatId: _settings.currentSettings.sourceChatId,
      fromMessageId: null,
      limit: messagePageSize,
    );
    _navigation.replaceMessages(page);
    tailMessageId = page.isEmpty ? null : page.last.id;
    if (page.isNotEmpty) {
      _startBackgroundPreviewPrefetch();
    }
  }

  Future<void> appendMoreMessages() async {
    if (!_state.isOnline.value || tailMessageId == null) {
      return;
    }
    final page = await _messages.fetchMessagePage(
      direction: _settings.currentSettings.fetchDirection,
      sourceChatId: _settings.currentSettings.sourceChatId,
      fromMessageId: tailMessageId,
      limit: messagePageSize,
    );
    if (page.isEmpty) {
      return;
    }
    _navigation.appendUniqueMessages(page);
    tailMessageId = _messageCache.last.id;
  }

  Future<void> prefetchIfNeeded() async {
    if (_shouldAppendMoreMessages()) {
      await appendMoreMessages();
    }
    await prepareUpcomingPreviews();
  }

  Future<void> ensureVisibleMessage() async {
    if (_navigation.isEmpty) {
      await appendMoreMessages();
    }
    _navigation.ensureCurrentAndSync();
    if (_navigation.isEmpty) {
      return;
    }
    await _refreshCurrentMediaIfNeeded?.call();
    await prefetchIfNeeded();
  }

  Future<void> refreshRemainingCount() async {
    await _remainingCount.refreshRemainingCount(
      loadCount: () => _messages.countRemainingMessages(
        sourceChatId: _settings.currentSettings.sourceChatId,
      ),
      onStart: () {
        _state.remainingCountLoading.value = true;
      },
      onSuccess: (nextCount) {
        _state.remainingCount.value = nextCount;
      },
      onError: (error) {
        _state.remainingCount.value = null;
        _reportGeneralError('剩余统计失败：$error');
      },
      onComplete: () {
        _state.remainingCountLoading.value = false;
      },
    );
  }

  Future<void> prepareUpcomingPreviews() async {
    final prefetchCount = _settings.currentSettings.previewPrefetchCount;
    if (prefetchCount <= 0 || _currentIndex < 0) {
      return;
    }
    final start = _currentIndex + 1;
    final end = math.min(_messageCache.length, start + prefetchCount);
    for (var index = start; index < end; index++) {
      final item = _messageCache[index];
      for (final messageId in item.messageIds) {
        if (!_previewPreparedMessageIds.add(messageId)) {
          continue;
        }
        try {
          await _media.prepareMediaPreview(
            sourceChatId: item.sourceChatId,
            messageId: messageId,
          );
        } catch (_) {
          _previewPreparedMessageIds.remove(messageId);
          rethrow;
        }
      }
    }
  }

  void _startBackgroundPreviewPrefetch() {
    unawaited(_prepareUpcomingPreviewsSafely());
  }

  Future<void> _prepareUpcomingPreviewsSafely() async {
    try {
      await prepareUpcomingPreviews();
    } catch (error) {
      _reportGeneralError(error);
    }
  }

  void reset() {
    _remainingCount.beginRequest();
    _navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    tailMessageId = null;
    _state.remainingCount.value = null;
    _state.remainingCountLoading.value = false;
  }

  void decrementRemainingCount(int delta) {
    final current = _state.remainingCount.value;
    if (current == null || current <= 0 || delta <= 0) {
      return;
    }
    _state.remainingCount.value = math.max(0, current - delta);
  }

  void incrementRemainingCount(int delta) {
    final current = _state.remainingCount.value;
    if (current == null || delta <= 0) {
      return;
    }
    _state.remainingCount.value = current + delta;
  }

  bool _shouldAppendMoreMessages() {
    final remaining = _messageCache.length - _currentIndex - 1;
    return remaining <= 2;
  }
}
