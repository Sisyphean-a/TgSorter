class RetryQueueItem {
  const RetryQueueItem({
    required this.id,
    required this.categoryKey,
    required this.sourceChatId,
    required this.messageIds,
    required this.targetChatId,
    required this.createdAtMs,
    required this.reason,
  });

  final String id;
  final String categoryKey;
  final int? sourceChatId;
  final List<int> messageIds;
  final int targetChatId;
  final int createdAtMs;
  final String reason;

  int get primaryMessageId => messageIds.first;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_key': categoryKey,
      'source_chat_id': sourceChatId,
      'message_ids': messageIds,
      'target_chat_id': targetChatId,
      'created_at_ms': createdAtMs,
      'reason': reason,
    };
  }

  factory RetryQueueItem.fromJson(Map<String, dynamic> json) {
    return RetryQueueItem(
      id: json['id'] as String,
      categoryKey: json['category_key'] as String,
      sourceChatId: json['source_chat_id'] as int?,
      messageIds: _readMessageIds(json),
      targetChatId: json['target_chat_id'] as int,
      createdAtMs: json['created_at_ms'] as int,
      reason: json['reason'] as String,
    );
  }

  static List<int> _readMessageIds(Map<String, dynamic> json) {
    final rawIds = json['message_ids'];
    if (rawIds is List) {
      return rawIds.map((item) => item as int).toList(growable: false);
    }
    final legacyId = json['message_id'];
    if (legacyId is int) {
      return [legacyId];
    }
    throw StateError('重试队列缺少 message_ids');
  }
}
