enum ClassifyTransactionStage {
  created,
  forwardConfirmed,
  sourceDeleteConfirmed,
  needsManualReview,
}

class ClassifyTransactionEntry {
  static const _unset = Object();

  const ClassifyTransactionEntry({
    required this.id,
    required this.sourceChatId,
    required this.sourceMessageIds,
    required this.targetChatId,
    required this.asCopy,
    required this.targetMessageIds,
    required this.stage,
    required this.createdAtMs,
    required this.updatedAtMs,
    required this.lastError,
  });

  final String id;
  final int sourceChatId;
  final List<int> sourceMessageIds;
  final int targetChatId;
  final bool asCopy;
  final List<int> targetMessageIds;
  final ClassifyTransactionStage stage;
  final int createdAtMs;
  final int updatedAtMs;
  final String? lastError;

  ClassifyTransactionEntry copyWith({
    String? id,
    int? sourceChatId,
    List<int>? sourceMessageIds,
    int? targetChatId,
    bool? asCopy,
    List<int>? targetMessageIds,
    ClassifyTransactionStage? stage,
    int? createdAtMs,
    int? updatedAtMs,
    Object? lastError = _unset,
  }) {
    return ClassifyTransactionEntry(
      id: id ?? this.id,
      sourceChatId: sourceChatId ?? this.sourceChatId,
      sourceMessageIds: sourceMessageIds ?? this.sourceMessageIds,
      targetChatId: targetChatId ?? this.targetChatId,
      asCopy: asCopy ?? this.asCopy,
      targetMessageIds: targetMessageIds ?? this.targetMessageIds,
      stage: stage ?? this.stage,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      lastError: identical(lastError, _unset)
          ? this.lastError
          : lastError as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'source_chat_id': sourceChatId,
      'source_message_ids': sourceMessageIds,
      'target_chat_id': targetChatId,
      'as_copy': asCopy,
      'target_message_ids': targetMessageIds,
      'stage': _stageToRaw(stage),
      'created_at_ms': createdAtMs,
      'updated_at_ms': updatedAtMs,
      'last_error': lastError,
    };
  }

  factory ClassifyTransactionEntry.fromJson(Map<String, dynamic> json) {
    final rawSourceIds = json['source_message_ids'];
    final sourceMessageIds = rawSourceIds is List
        ? rawSourceIds.map((item) => item as int).toList(growable: false)
        : <int>[];
    final rawTargetIds = json['target_message_ids'];
    final targetMessageIds = rawTargetIds is List
        ? rawTargetIds.map((item) => item as int).toList(growable: false)
        : <int>[];
    return ClassifyTransactionEntry(
      id: json['id'] as String,
      sourceChatId: json['source_chat_id'] as int,
      sourceMessageIds: sourceMessageIds,
      targetChatId: json['target_chat_id'] as int,
      asCopy: (json['as_copy'] as bool?) ?? false,
      targetMessageIds: targetMessageIds,
      stage: _rawToStage(json['stage'] as String),
      createdAtMs: json['created_at_ms'] as int,
      updatedAtMs: json['updated_at_ms'] as int,
      lastError: json['last_error'] as String?,
    );
  }

  static String _stageToRaw(ClassifyTransactionStage stage) {
    switch (stage) {
      case ClassifyTransactionStage.created:
        return 'created';
      case ClassifyTransactionStage.forwardConfirmed:
        return 'forward_confirmed';
      case ClassifyTransactionStage.sourceDeleteConfirmed:
        return 'source_delete_confirmed';
      case ClassifyTransactionStage.needsManualReview:
        return 'needs_manual_review';
    }
  }

  static ClassifyTransactionStage _rawToStage(String raw) {
    switch (raw) {
      case 'created':
        return ClassifyTransactionStage.created;
      case 'forward_confirmed':
        return ClassifyTransactionStage.forwardConfirmed;
      case 'source_delete_confirmed':
        return ClassifyTransactionStage.sourceDeleteConfirmed;
      case 'needs_manual_review':
        return ClassifyTransactionStage.needsManualReview;
      default:
        throw StateError('未知分类事务状态: $raw');
    }
  }
}
