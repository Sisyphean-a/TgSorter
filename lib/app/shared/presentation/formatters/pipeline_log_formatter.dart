import 'package:tgsorter/app/models/classify_operation_log.dart';

enum PipelineLogFilter { all, failedInProgress, recovered, skippedOrUndone }

enum PipelineLogChainState {
  completed,
  failedInProgress,
  recovered,
  skippedOrUndone,
}

class PipelineLogEventViewModel {
  const PipelineLogEventViewModel({
    required this.id,
    required this.timestamp,
    required this.status,
    required this.statusLabel,
    this.reason,
  });

  final String id;
  final DateTime timestamp;
  final ClassifyOperationStatus status;
  final String statusLabel;
  final String? reason;
}

class PipelineLogChainViewModel {
  const PipelineLogChainViewModel({
    required this.chainKey,
    required this.messageId,
    required this.categoryKey,
    required this.targetChatId,
    required this.firstOccurredAt,
    required this.lastOccurredAt,
    required this.state,
    required this.statusLabel,
    required this.summaryLabel,
    required this.latestReason,
    required this.events,
  });

  final String chainKey;
  final int messageId;
  final String categoryKey;
  final int targetChatId;
  final DateTime firstOccurredAt;
  final DateTime lastOccurredAt;
  final PipelineLogChainState state;
  final String statusLabel;
  final String summaryLabel;
  final String? latestReason;
  final List<PipelineLogEventViewModel> events;
}

List<PipelineLogChainViewModel> buildPipelineLogChains(
  List<ClassifyOperationLog> logs,
) {
  final groups = <String, List<ClassifyOperationLog>>{};
  for (final log in logs) {
    groups
        .putIfAbsent(_chainKeyOf(log), () => <ClassifyOperationLog>[])
        .add(log);
  }
  final chains = groups.entries
      .map((entry) => _toChain(entry.key, entry.value))
      .toList(growable: false);
  chains.sort((left, right) {
    final stateDiff = _sortWeight(left.state) - _sortWeight(right.state);
    if (stateDiff != 0) {
      return stateDiff;
    }
    return right.lastOccurredAt.compareTo(left.lastOccurredAt);
  });
  return chains;
}

List<PipelineLogChainViewModel> filterPipelineLogChains(
  List<PipelineLogChainViewModel> chains,
  PipelineLogFilter filter,
) {
  if (filter == PipelineLogFilter.all) {
    return chains;
  }
  return chains
      .where((chain) => _matchesFilter(chain.state, filter))
      .toList(growable: false);
}

String formatPipelineLog(ClassifyOperationLog log) {
  final time = DateTime.fromMillisecondsSinceEpoch(log.createdAtMs);
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  final ss = time.second.toString().padLeft(2, '0');
  final suffix = log.reason == null ? '' : ' ${log.reason}';
  return '[$hh:$mm:$ss] ${_labelStatus(log.status)} m:${log.messageId} -> ${log.targetChatId}$suffix';
}

PipelineLogChainViewModel _toChain(
  String key,
  List<ClassifyOperationLog> logs,
) {
  logs.sort((left, right) => left.createdAtMs.compareTo(right.createdAtMs));
  final first = logs.first;
  final last = logs.last;
  final events = logs
      .map(
        (log) => PipelineLogEventViewModel(
          id: log.id,
          timestamp: DateTime.fromMillisecondsSinceEpoch(log.createdAtMs),
          status: log.status,
          statusLabel: _labelStatus(log.status),
          reason: log.reason,
        ),
      )
      .toList(growable: false);
  final state = _resolveState(logs);
  return PipelineLogChainViewModel(
    chainKey: key,
    messageId: first.messageId,
    categoryKey: first.categoryKey,
    targetChatId: first.targetChatId,
    firstOccurredAt: DateTime.fromMillisecondsSinceEpoch(first.createdAtMs),
    lastOccurredAt: DateTime.fromMillisecondsSinceEpoch(last.createdAtMs),
    state: state,
    statusLabel: _stateLabel(state),
    summaryLabel: _summaryLabel(events),
    latestReason: _latestReason(events),
    events: events,
  );
}

String _chainKeyOf(ClassifyOperationLog log) {
  return '${log.messageId}_${log.categoryKey}_${log.targetChatId}';
}

PipelineLogChainState _resolveState(List<ClassifyOperationLog> logs) {
  final last = logs.last.status;
  final hadFailure = logs.any(
    (log) =>
        log.status == ClassifyOperationStatus.failed ||
        log.status == ClassifyOperationStatus.retryFailed ||
        log.status == ClassifyOperationStatus.mediaFailed ||
        log.status == ClassifyOperationStatus.mediaRetryFailed ||
        log.status == ClassifyOperationStatus.undoFailed,
  );
  if (last == ClassifyOperationStatus.skipped ||
      last == ClassifyOperationStatus.undoSuccess) {
    return PipelineLogChainState.skippedOrUndone;
  }
  if (last == ClassifyOperationStatus.failed ||
      last == ClassifyOperationStatus.retryFailed ||
      last == ClassifyOperationStatus.mediaFailed ||
      last == ClassifyOperationStatus.mediaRetryFailed ||
      last == ClassifyOperationStatus.undoFailed) {
    return PipelineLogChainState.failedInProgress;
  }
  if (hadFailure &&
      (last == ClassifyOperationStatus.retrySuccess ||
          last == ClassifyOperationStatus.mediaRetrySuccess ||
          last == ClassifyOperationStatus.success)) {
    return PipelineLogChainState.recovered;
  }
  return PipelineLogChainState.completed;
}

bool _matchesFilter(PipelineLogChainState state, PipelineLogFilter filter) {
  switch (filter) {
    case PipelineLogFilter.all:
      return true;
    case PipelineLogFilter.failedInProgress:
      return state == PipelineLogChainState.failedInProgress;
    case PipelineLogFilter.recovered:
      return state == PipelineLogChainState.recovered;
    case PipelineLogFilter.skippedOrUndone:
      return state == PipelineLogChainState.skippedOrUndone;
  }
}

int _sortWeight(PipelineLogChainState state) {
  switch (state) {
    case PipelineLogChainState.failedInProgress:
      return 0;
    case PipelineLogChainState.recovered:
      return 1;
    case PipelineLogChainState.skippedOrUndone:
      return 2;
    case PipelineLogChainState.completed:
      return 3;
  }
}

String _stateLabel(PipelineLogChainState state) {
  switch (state) {
    case PipelineLogChainState.completed:
      return '已完成';
    case PipelineLogChainState.failedInProgress:
      return '失败中';
    case PipelineLogChainState.recovered:
      return '已恢复';
    case PipelineLogChainState.skippedOrUndone:
      return '已跳过/已撤销';
  }
}

String _labelStatus(ClassifyOperationStatus status) {
  switch (status) {
    case ClassifyOperationStatus.success:
      return '成功';
    case ClassifyOperationStatus.failed:
      return '失败';
    case ClassifyOperationStatus.retrySuccess:
      return '重试成功';
    case ClassifyOperationStatus.retryFailed:
      return '重试失败';
    case ClassifyOperationStatus.mediaFailed:
      return '媒体失败';
    case ClassifyOperationStatus.mediaRetrySuccess:
      return '媒体重试成功';
    case ClassifyOperationStatus.mediaRetryFailed:
      return '媒体重试失败';
    case ClassifyOperationStatus.skipped:
      return '跳过';
    case ClassifyOperationStatus.undoSuccess:
      return '撤销成功';
    case ClassifyOperationStatus.undoFailed:
      return '撤销失败';
  }
}

String _summaryLabel(List<PipelineLogEventViewModel> events) {
  if (events.isEmpty) {
    return '无事件';
  }
  final labels = <String>[];
  for (final event in events) {
    if (labels.isEmpty || labels.last != event.statusLabel) {
      labels.add(event.statusLabel);
    }
  }
  return labels.join(' -> ');
}

String? _latestReason(List<PipelineLogEventViewModel> events) {
  for (final event in events.reversed) {
    final reason = event.reason;
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
  }
  return null;
}
