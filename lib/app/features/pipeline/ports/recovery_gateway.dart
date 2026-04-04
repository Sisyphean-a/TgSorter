class ClassifyRecoverySummary {
  const ClassifyRecoverySummary({
    required this.recoveredCount,
    required this.manualReviewCount,
    required this.failedCount,
  });

  static const empty = ClassifyRecoverySummary(
    recoveredCount: 0,
    manualReviewCount: 0,
    failedCount: 0,
  );

  final int recoveredCount;
  final int manualReviewCount;
  final int failedCount;
}

/// Pipeline feature 依赖的最小恢复能力接口（capability port）。
abstract class RecoveryGateway {
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}

abstract class RecoverableClassifyGateway implements RecoveryGateway {
  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}
