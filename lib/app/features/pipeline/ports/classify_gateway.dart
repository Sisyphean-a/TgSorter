class ClassifyReceipt {
  ClassifyReceipt({
    required this.sourceChatId,
    required List<int> sourceMessageIds,
    required this.targetChatId,
    required List<int> targetMessageIds,
  }) : sourceMessageIds = List<int>.unmodifiable(sourceMessageIds),
       targetMessageIds = List<int>.unmodifiable(targetMessageIds);

  final int sourceChatId;
  final List<int> sourceMessageIds;
  final int targetChatId;
  final List<int> targetMessageIds;

  int get primarySourceMessageId => sourceMessageIds.first;
}

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
