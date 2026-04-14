enum SkippedMessageWorkflow { forwarding, tagging }

class SkippedMessageRecord {
  const SkippedMessageRecord({
    required this.id,
    required this.workflow,
    required this.sourceChatId,
    required this.primaryMessageId,
    required this.messageIds,
    required this.createdAtMs,
  });

  final String id;
  final SkippedMessageWorkflow workflow;
  final int sourceChatId;
  final int primaryMessageId;
  final List<int> messageIds;
  final int createdAtMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'workflow': workflow.name,
      'sourceChatId': sourceChatId,
      'primaryMessageId': primaryMessageId,
      'messageIds': messageIds,
      'createdAtMs': createdAtMs,
    };
  }

  factory SkippedMessageRecord.fromJson(Map<String, dynamic> json) {
    return SkippedMessageRecord(
      id: json['id'] as String? ?? '',
      workflow: _workflowFromJson(json['workflow'] as String?),
      sourceChatId: (json['sourceChatId'] as num?)?.toInt() ?? 0,
      primaryMessageId: (json['primaryMessageId'] as num?)?.toInt() ?? 0,
      messageIds: ((json['messageIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => (item as num).toInt())
          .toList(growable: false)),
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  static SkippedMessageWorkflow _workflowFromJson(String? raw) {
    if (raw == SkippedMessageWorkflow.tagging.name) {
      return SkippedMessageWorkflow.tagging;
    }
    return SkippedMessageWorkflow.forwarding;
  }
}
