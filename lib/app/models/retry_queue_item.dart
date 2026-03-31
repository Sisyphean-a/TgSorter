class RetryQueueItem {
  const RetryQueueItem({
    required this.id,
    required this.categoryKey,
    required this.messageId,
    required this.targetChatId,
    required this.createdAtMs,
    required this.reason,
  });

  final String id;
  final String categoryKey;
  final int messageId;
  final int targetChatId;
  final int createdAtMs;
  final String reason;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_key': categoryKey,
      'message_id': messageId,
      'target_chat_id': targetChatId,
      'created_at_ms': createdAtMs,
      'reason': reason,
    };
  }

  factory RetryQueueItem.fromJson(Map<String, dynamic> json) {
    return RetryQueueItem(
      id: json['id'] as String,
      categoryKey: json['category_key'] as String,
      messageId: json['message_id'] as int,
      targetChatId: json['target_chat_id'] as int,
      createdAtMs: json['created_at_ms'] as int,
      reason: json['reason'] as String,
    );
  }
}
