import 'package:tgsorter/app/services/skipped_message_repository.dart';

class SkippedMessageSummary {
  const SkippedMessageSummary({
    required this.totalCount,
    required this.forwardingCount,
    required this.taggingCount,
    required this.sources,
  });

  const SkippedMessageSummary.empty()
    : totalCount = 0,
      forwardingCount = 0,
      taggingCount = 0,
      sources = const <SkippedMessageSourceSummary>[];

  final int totalCount;
  final int forwardingCount;
  final int taggingCount;
  final List<SkippedMessageSourceSummary> sources;

  factory SkippedMessageSummary.fromRecords(
    List<SkippedMessageRecord> records,
  ) {
    if (records.isEmpty) {
      return const SkippedMessageSummary.empty();
    }
    var forwardingCount = 0;
    var taggingCount = 0;
    final sourceCounts = <String, int>{};
    final sourceSummaries = <String, SkippedMessageSourceSummary>{};
    for (final record in records) {
      switch (record.workflow) {
        case SkippedMessageWorkflow.forwarding:
          forwardingCount++;
          break;
        case SkippedMessageWorkflow.tagging:
          taggingCount++;
          break;
      }
      final key = '${record.workflow.name}:${record.sourceChatId}';
      sourceCounts.update(key, (value) => value + 1, ifAbsent: () => 1);
      sourceSummaries[key] = SkippedMessageSourceSummary(
        workflow: record.workflow,
        sourceChatId: record.sourceChatId,
        count: sourceCounts[key]!,
      );
    }
    final sources = sourceSummaries.values.toList(growable: false)
      ..sort((left, right) {
        final countCompare = right.count.compareTo(left.count);
        if (countCompare != 0) {
          return countCompare;
        }
        final workflowCompare = left.workflow.name.compareTo(
          right.workflow.name,
        );
        if (workflowCompare != 0) {
          return workflowCompare;
        }
        return left.sourceChatId.compareTo(right.sourceChatId);
      });
    return SkippedMessageSummary(
      totalCount: records.length,
      forwardingCount: forwardingCount,
      taggingCount: taggingCount,
      sources: sources,
    );
  }
}

class SkippedMessageSourceSummary {
  const SkippedMessageSourceSummary({
    required this.workflow,
    required this.sourceChatId,
    required this.count,
  });

  final SkippedMessageWorkflow workflow;
  final int sourceChatId;
  final int count;
}
