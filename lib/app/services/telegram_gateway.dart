import 'package:tgsorter/app/features/auth/application/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/application/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/application/session_query_gateway.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

class SelectableChat {
  const SelectableChat({required this.id, required this.title});

  final int id;
  final String title;
}

class ClassifyReceipt {
  const ClassifyReceipt({
    required this.sourceChatId,
    required this.sourceMessageIds,
    required this.targetChatId,
    required this.targetMessageIds,
  });

  final int sourceChatId;
  final List<int> sourceMessageIds;
  final int targetChatId;
  final List<int> targetMessageIds;

  int get primarySourceMessageId => sourceMessageIds.first;
}

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

abstract class RecoverableClassifyGateway implements RecoveryGateway {
  @override
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}

/// 过渡期保留的聚合网关，后续将逐步由 capability interface 替代。
abstract class TelegramGateway
    implements
        AuthGateway,
        SessionQueryGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway {
  Stream<TdConnectionState> get connectionStates;
}
