import 'package:tgsorter/app/controllers/app_error_controller.dart';

import 'recovery_gateway.dart';

class PipelineRecoveryService {
  PipelineRecoveryService({
    required RecoveryGateway? recoveryGateway,
    required AppErrorController errors,
  }) : _recoveryGateway = recoveryGateway,
       _errors = errors;

  final RecoveryGateway? _recoveryGateway;
  final AppErrorController _errors;
  bool _completed = false;
  bool _running = false;

  bool get isCompleted => _completed;
  bool get isRunning => _running;

  Future<void> recoverPendingTransactionsIfNeeded() async {
    if (_completed || _running) {
      return;
    }
    final recoveryGateway = _recoveryGateway;
    if (recoveryGateway == null) {
      _completed = true;
      return;
    }
    _running = true;
    try {
      final summary = await recoveryGateway.recoverPendingClassifyOperations();
      _completed = true;
      if (summary.failedCount > 0 || summary.manualReviewCount > 0) {
        _errors.report(
          title: '分类事务恢复提醒',
          message:
              '自动恢复 ${summary.recoveredCount} 条，'
              '仍有 ${summary.manualReviewCount} 条需要人工核查，'
              '${summary.failedCount} 条恢复失败',
        );
      }
    } catch (error) {
      _errors.report(title: '分类事务恢复失败', message: '$error');
      _completed = true;
    } finally {
      _running = false;
    }
  }
}
