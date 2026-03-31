enum ClassifyOperationStatus { success, failed, retrySuccess, retryFailed }

class ClassifyOperationLog {
  const ClassifyOperationLog({
    required this.id,
    required this.categoryKey,
    required this.messageId,
    required this.targetChatId,
    required this.createdAtMs,
    required this.status,
    this.reason,
  });

  final String id;
  final String categoryKey;
  final int messageId;
  final int targetChatId;
  final int createdAtMs;
  final ClassifyOperationStatus status;
  final String? reason;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_key': categoryKey,
      'message_id': messageId,
      'target_chat_id': targetChatId,
      'created_at_ms': createdAtMs,
      'status': _statusToRaw(status),
      'reason': reason,
    };
  }

  factory ClassifyOperationLog.fromJson(Map<String, dynamic> json) {
    return ClassifyOperationLog(
      id: json['id'] as String,
      categoryKey: json['category_key'] as String,
      messageId: json['message_id'] as int,
      targetChatId: json['target_chat_id'] as int,
      createdAtMs: json['created_at_ms'] as int,
      status: _rawToStatus(json['status'] as String),
      reason: json['reason'] as String?,
    );
  }

  static String _statusToRaw(ClassifyOperationStatus value) {
    switch (value) {
      case ClassifyOperationStatus.success:
        return 'success';
      case ClassifyOperationStatus.failed:
        return 'failed';
      case ClassifyOperationStatus.retrySuccess:
        return 'retry_success';
      case ClassifyOperationStatus.retryFailed:
        return 'retry_failed';
    }
  }

  static ClassifyOperationStatus _rawToStatus(String value) {
    switch (value) {
      case 'success':
        return ClassifyOperationStatus.success;
      case 'failed':
        return ClassifyOperationStatus.failed;
      case 'retry_success':
        return ClassifyOperationStatus.retrySuccess;
      case 'retry_failed':
        return ClassifyOperationStatus.retryFailed;
      default:
        throw StateError('未知日志状态: $value');
    }
  }
}
