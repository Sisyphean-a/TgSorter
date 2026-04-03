import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/features/pipeline/application/recovery_gateway.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  test('recoverPendingTransactions reports recovered count once', () async {
    final harness = _PipelineRecoveryHarness.success();
    final service = harness.build();

    await service.recoverPendingTransactionsIfNeeded();
    await service.recoverPendingTransactionsIfNeeded();

    expect(harness.recoverCalls, 1);
  });
}

class _PipelineRecoveryHarness {
  _PipelineRecoveryHarness._({
    required this.recoveryGateway,
    required this.errorController,
  });

  factory _PipelineRecoveryHarness.success() {
    return _PipelineRecoveryHarness._(
      recoveryGateway: _FakeRecoveryGateway(),
      errorController: _RecordingErrorController(),
    );
  }

  final _FakeRecoveryGateway recoveryGateway;
  final _RecordingErrorController errorController;

  int get recoverCalls => recoveryGateway.recoverCalls;

  PipelineRecoveryService build() {
    return PipelineRecoveryService(
      recoveryGateway: recoveryGateway,
      errors: errorController,
    );
  }
}

class _FakeRecoveryGateway implements RecoveryGateway {
  int recoverCalls = 0;

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    recoverCalls++;
    return ClassifyRecoverySummary.empty;
  }
}

class _RecordingErrorController extends AppErrorController {
  final List<String> messages = <String>[];

  @override
  void report({required String title, required String message}) {
    messages.add('$title::$message');
    super.report(title: title, message: message);
  }
}
