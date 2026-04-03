import 'package:tgsorter/app/controllers/app_error_controller.dart';

import 'recovery_gateway.dart';

class PipelineRecoveryService {
  PipelineRecoveryService({
    required RecoveryGateway recoveryGateway,
    required AppErrorController errors,
  }) : _recoveryGateway = recoveryGateway,
       _errors = errors;

  final RecoveryGateway _recoveryGateway;
  final AppErrorController _errors;
  bool _completed = false;
  bool _running = false;

  Future<void> recoverPendingTransactionsIfNeeded() async {
    if (_completed || _running) {
      return;
    }
    _running = true;
    try {
      final summary = await _recoveryGateway.recoverPendingClassifyOperations();
      _completed = true;
      if (summary.failedCount > 0) {
        _errors.report(title: '恢复失败', message: '存在未恢复事务');
      }
    } finally {
      _running = false;
    }
  }
}
