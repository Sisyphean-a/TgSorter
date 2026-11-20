import 'dart:async';
import 'dart:math' as math;

import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'pipeline_prepared_message_merger.dart';
import 'pipeline_navigation_service.dart';
import 'pipeline_runtime_state.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'remaining_count_service.dart';

class PipelineFeedController {
  static const int messagePageSize = 20;

  PipelineFeedController({
    required this._state,
    required this._navigation,
    required this._messages,
    required this._media,
    required this._settings,
    required this._remainingCount,
    required this._reportGeneralError,
    SkippedMessageRepository? skippedMessageRepository,
    this._workflow = SkippedMessageWorkflow.forwarding,
    this._refreshCurrentMediaIfNeeded,
  }) : _skippedMessageRepository =
           skippedMessageRepository ?? NoopSkippedMessageRepository.instance;

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
    _appendTask = null;
    _state.historyExhausted = false;
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
    _state.historyExhausted = page.exhausted;
    tailMessageId = page.exhausted ? null : page.tailMessageId;
    _navigation.replaceMessages(page.messages);
    if (page.messages.isNotEmpty) {
      _startBackgroundPreviewPrefetch();
    }
  }

  Future<void>? _appendTask;

  Future<void> appendMoreMessages() async {
    final pending = _appendTask;
    if (pending != null) {
      return pending;
    }
    final cursor = tailMessageId;
    if (!_state.isOnline.value || cursor == null) {
      return;
    }
    final task = _appendPage(_feedSession, cursor);
    _appendTask = task;
    try {
      await task;
    } finally {
      if (identical(_appendTask, task)) {
        _appendTask = null;
      }
    }
  }

  Future<void> _appendPage(int session, int cursor) async {
    final page = await _fetchVisiblePage(
      fromMessageId: cursor,
      limit: messagePageSize,
    );
    if (session != _feedSession) {
      return;
    }
    tailMessageId = page.exhausted ? null : page.tailMessageId;
    _state.historyExhausted = page.exhausted;
    if (page.messages.isEmpty) {
      _navigation.syncNavigationState();
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
            await _refreshPreparedMessage(
              session: session,
              sourceChatId: item.sourceChatId,
              messageId: messageId,
            );
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

  Future<void> _refreshPreparedMessage({
    required int session,
    required int sourceChatId,
    required int messageId,
  }) async {
    final refreshed = await _messages.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
    if (session != _feedSession) {
      return;
    }
    final current = _messageContaining(messageId);
    if (current == null) {
      return;
    }
    _replaceCachedMessage(mergePreparedMessage(current, refreshed));
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
    _appendTask = null;
    _state.historyExhausted = false;
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

  PipelineMessage? _messageContaining(int messageId) {
    for (final item in _messageCache) {
      if (item.messageIds.contains(messageId)) {
        return item;
      }
    }
    return null;
  }

  void _replaceCachedMessage(PipelineMessage message) {
    final index = _messageCache.indexWhere((item) => item.id == message.id);
    if (index < 0) {
      return;
    }
    _messageCache[index] = message;
    if (_state.currentIndex == index) {
      _navigation.syncCurrentMessage();
      return;
    }
    _navigation.syncNavigationState();
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
      final last = page.last;
      // 相册内按正序显示；分页游标须取扫描方向上最后一条原始消息。
      final nextCursor = direction == MessageFetchDirection.oldestFirst
          ? last.messageIds.last
          : last.messageIds.first;
      if (nextCursor == cursor) {
        throw StateError('消息分页游标未前进：$nextCursor');
      }
      lastRawMessageId = nextCursor;
      cursor = nextCursor;
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
    return messages
        .where((item) {
          return !_skippedMessageRepository.containsMessage(
            workflow: _workflow,
            sourceChatId: item.sourceChatId,
            messageIds: item.messageIds,
          );
        })
        .toList(growable: false);
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
