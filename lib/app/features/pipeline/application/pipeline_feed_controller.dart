import 'dart:async';
import 'dart:math' as math;

import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

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
    SkippedMessageRepository? skippedMessageRepository,
    SkippedMessageWorkflow workflow = SkippedMessageWorkflow.forwarding,
    Future<void> Function()? refreshCurrentMediaIfNeeded,
  }) : _state = state,
       _navigation = navigation,
       _messages = messages,
       _media = media,
       _settings = settings,
       _remainingCount = remainingCount,
       _reportGeneralError = reportGeneralError,
       _skippedMessageRepository =
           skippedMessageRepository ?? NoopSkippedMessageRepository.instance,
       _workflow = workflow,
       _refreshCurrentMediaIfNeeded = refreshCurrentMediaIfNeeded;

  final PipelineRuntimeState _state;
  final PipelineNavigationService _navigation;
  final MessageReadGateway _messages;
  final MediaGateway _media;
  final PipelineSettingsReader _settings;
  final RemainingCountService _remainingCount;
  final void Function(Object error) _reportGeneralError;
  final SkippedMessageRepository _skippedMessageRepository;
  final SkippedMessageWorkflow _workflow;
  final Future<void> Function()? _refreshCurrentMediaIfNeeded;

  int? tailMessageId;
  final Set<int> _previewPreparedMessageIds = <int>{};
  int _feedSession = 0;

  int get _currentIndex => _state.currentIndex;
  List<PipelineMessage> get _messageCache => _state.cache;

  Future<void> loadInitialMessages() async {
    final session = ++_feedSession;
    unawaited(refreshRemainingCount());
    _navigation.replaceMessages(const <PipelineMessage>[]);
    _previewPreparedMessageIds.clear();
    tailMessageId = null;
    final page = await _fetchVisiblePage(
      fromMessageId: null,
      limit: messagePageSize,
    );
    if (session != _feedSession) {
      return;
    }
    _navigation.replaceMessages(page.messages);
    tailMessageId = page.exhausted ? null : page.tailMessageId;
    if (page.messages.isNotEmpty) {
      _startBackgroundPreviewPrefetch();
    }
  }

  Future<void> appendMoreMessages() async {
    if (!_state.isOnline.value || tailMessageId == null) {
      return;
    }
    final session = _feedSession;
    final page = await _fetchVisiblePage(
      fromMessageId: tailMessageId,
      limit: messagePageSize,
    );
    if (session != _feedSession) {
      return;
    }
    tailMessageId = page.exhausted ? null : page.tailMessageId;
    if (page.messages.isEmpty) {
      return;
    }
    _navigation.appendUniqueMessages(page.messages);
  }

  Future<void> prefetchIfNeeded() async {
    if (_shouldAppendMoreMessages()) {
      await appendMoreMessages();
    }
    _startBackgroundPreviewPrefetch();
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
      loadCount: () async {
        final sourceChatId = _settings.currentSettings.sourceChatId;
        final count = await _messages.countRemainingMessages(
          sourceChatId: sourceChatId,
        );
        if (sourceChatId == null) {
          return count;
        }
        return math.max(
          0,
          count -
              _skippedMessageRepository.countSkippedMessages(
                workflow: _workflow,
                sourceChatId: sourceChatId,
              ),
        );
      },
      onStart: () {
        _state.remainingCountLoading.value = true;
      },
      onSuccess: (nextCount) {
        _state.remainingCount.value = nextCount;
        _navigation.syncNavigationState();
      },
      onError: (error) {
        _state.remainingCount.value = null;
        _navigation.syncNavigationState();
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
    final backgroundConcurrency = math.max(
      1,
      _settings.currentSettings.mediaBackgroundDownloadConcurrency,
    );
    final session = _feedSession;
    final start = _currentIndex + 1;
    final end = math.min(_messageCache.length, start + prefetchCount);
    final items = _messageCache.sublist(start, end).toList(growable: false);
    if (items.isEmpty) {
      return;
    }

    var nextIndex = 0;
    Object? firstError;

    Future<void> worker() async {
      while (nextIndex < items.length) {
        if (session != _feedSession) {
          return;
        }
        if (firstError != null) {
          return;
        }
        final item = items[nextIndex++];
        for (final messageId in item.messageIds) {
          if (session != _feedSession) {
            return;
          }
          if (firstError != null) {
            return;
          }
          if (!_previewPreparedMessageIds.add(messageId)) {
            continue;
          }
          try {
            await _media.prepareMediaPreview(
              sourceChatId: item.sourceChatId,
              messageId: messageId,
            );
            if (session != _feedSession) {
              _previewPreparedMessageIds.remove(messageId);
              return;
            }
          } catch (error) {
            _previewPreparedMessageIds.remove(messageId);
            firstError ??= error;
            return;
          }
        }
      }
    }

    await Future.wait(
      List<Future<void>>.generate(
        math.min(backgroundConcurrency, items.length),
        (_) => worker(),
      ),
    );
    if (firstError != null) {
      throw firstError!;
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
    _feedSession++;
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
    _navigation.syncNavigationState();
  }

  void incrementRemainingCount(int delta) {
    final current = _state.remainingCount.value;
    if (current == null || delta <= 0) {
      return;
    }
    _state.remainingCount.value = current + delta;
    _navigation.syncNavigationState();
  }

  bool _shouldAppendMoreMessages() {
    final remaining = _messageCache.length - _currentIndex - 1;
    return remaining <= 2;
  }

  Future<_VisiblePageResult> _fetchVisiblePage({
    required int? fromMessageId,
    required int limit,
  }) async {
    final direction = _settings.currentSettings.fetchDirection;
    final sourceChatId = _settings.currentSettings.sourceChatId;
    var cursor = fromMessageId;
    int? lastRawMessageId;
    var exhausted = false;
    while (true) {
      final page = await _messages.fetchMessagePage(
        direction: direction,
        sourceChatId: sourceChatId,
        fromMessageId: cursor,
        limit: limit,
      );
      if (page.isEmpty) {
        exhausted = true;
        break;
      }
      lastRawMessageId = page.last.id;
      cursor = lastRawMessageId;
      final visible = _filterSkippedMessages(page);
      if (visible.isNotEmpty) {
        return _VisiblePageResult(
          messages: visible,
          tailMessageId: lastRawMessageId,
          exhausted: false,
        );
      }
    }
    return _VisiblePageResult(
      messages: const <PipelineMessage>[],
      tailMessageId: lastRawMessageId,
      exhausted: exhausted,
    );
  }

  List<PipelineMessage> _filterSkippedMessages(List<PipelineMessage> messages) {
    return messages.where((item) {
      return !_skippedMessageRepository.containsMessage(
        workflow: _workflow,
        sourceChatId: item.sourceChatId,
        messageIds: item.messageIds,
      );
    }).toList(growable: false);
  }
}

class _VisiblePageResult {
  const _VisiblePageResult({
    required this.messages,
    required this.tailMessageId,
    required this.exhausted,
  });

  final List<PipelineMessage> messages;
  final int? tailMessageId;
  final bool exhausted;
}
