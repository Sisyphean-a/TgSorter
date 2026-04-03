import 'package:tgsorter/app/services/telegram_gateway.dart';

abstract class RecoveryGateway {
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}
