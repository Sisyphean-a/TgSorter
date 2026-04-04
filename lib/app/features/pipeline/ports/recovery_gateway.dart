import 'package:tgsorter/app/services/telegram_gateway.dart';

/// Pipeline feature 依赖的最小恢复能力接口（capability port）。
abstract class RecoveryGateway {
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}

