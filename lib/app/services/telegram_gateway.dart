import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
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

abstract class RecoverableClassifyGateway {
  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations();
}

/// 过渡期保留的聚合网关，后续将逐步由 capability interface 替代。
abstract class TelegramGateway {
  Stream<TdAuthState> get authStates;
  Stream<TdConnectionState> get connectionStates;

  Future<void> start();
  Future<void> restart();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);

  Future<List<SelectableChat>> listSelectableChats();
  Future<int> countRemainingMessages({required int? sourceChatId});

  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  });

  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  });

  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  });

  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  });

  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  });

  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  });

  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  });
}
