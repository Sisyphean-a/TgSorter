import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_recovery_service.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

void main() {
  test('recoverPendingTransactions reports recovered count once', () async {
    final harness = _PipelineRecoveryHarness.success();
    final service = harness.build();

    await service.recoverPendingTransactionsIfNeeded();
    await service.recoverPendingTransactionsIfNeeded();

    expect(harness.recoverCalls, 1);
  });

  test(
    'recoverPendingTransactions reports failure summary to error controller',
    () async {
      final harness = _PipelineRecoveryHarness.failure();
      final service = harness.build();

      await service.recoverPendingTransactionsIfNeeded();

      expect(harness.errorMessages.single, contains('恢复失败'));
    },
  );
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

  factory _PipelineRecoveryHarness.failure() {
    return _PipelineRecoveryHarness._(
      recoveryGateway: _FakeRecoveryGateway(
        summary: const ClassifyRecoverySummary(
          recoveredCount: 1,
          manualReviewCount: 0,
          failedCount: 2,
        ),
      ),
      errorController: _RecordingErrorController(),
    );
  }

  final _FakeRecoveryGateway recoveryGateway;
  final _RecordingErrorController errorController;

  int get recoverCalls => recoveryGateway.recoverCalls;
  List<String> get errorMessages => errorController.messages;

  PipelineRecoveryService build() {
    return PipelineRecoveryService(
      recoveryGateway: recoveryGateway,
      errors: errorController,
    );
  }
}

class _FakeRecoveryGateway implements RecoveryGateway {
  _FakeRecoveryGateway({this.summary = ClassifyRecoverySummary.empty});

  final ClassifyRecoverySummary summary;
  int recoverCalls = 0;

  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() async {
    recoverCalls++;
    return summary;
  }
}

class _RecordingErrorController extends AppErrorController {
  final List<String> messages = <String>[];

  @override
  void report({
    AppErrorScope scope = AppErrorScope.runtime,
    AppErrorLevel level = AppErrorLevel.error,
    required String title,
    required String message,
  }) {
    messages.add('$title::$message');
    super.report(scope: scope, level: level, title: title, message: message);
  }
}
