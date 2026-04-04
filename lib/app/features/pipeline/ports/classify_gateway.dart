import 'package:tgsorter/app/services/telegram_gateway.dart';

/// Pipeline feature 依赖的最小分类能力接口（capability port）。
abstract class ClassifyGateway {
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

