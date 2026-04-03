import 'package:tgsorter/app/models/classify_operation_log.dart';

String formatPipelineLog(ClassifyOperationLog log) {
  final time = DateTime.fromMillisecondsSinceEpoch(log.createdAtMs);
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  final ss = time.second.toString().padLeft(2, '0');
  final status = _labelStatus(log.status);
  final suffix = log.reason == null ? '' : ' ${log.reason}';
  return '[$hh:$mm:$ss] $status m:${log.messageId} -> ${log.targetChatId}$suffix';
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
    case ClassifyOperationStatus.skipped:
      return '跳过';
    case ClassifyOperationStatus.undoSuccess:
      return '撤销成功';
    case ClassifyOperationStatus.undoFailed:
      return '撤销失败';
  }
}
