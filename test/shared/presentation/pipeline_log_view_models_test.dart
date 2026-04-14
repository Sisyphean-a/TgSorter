import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/shared/presentation/formatters/pipeline_log_formatter.dart';

void main() {
  test('groups failure and retry success into one recovered chain', () {
    final chains = buildPipelineLogChains([
      _log(
        id: '1',
        createdAtMs: 1000,
        status: ClassifyOperationStatus.failed,
        reason: 'CHAT_WRITE_FORBIDDEN',
      ),
      _log(
        id: '2',
        createdAtMs: 2000,
        status: ClassifyOperationStatus.retrySuccess,
      ),
    ]);

    expect(chains, hasLength(1));
    expect(chains.single.state, PipelineLogChainState.recovered);
    expect(chains.single.events, hasLength(2));
    expect(chains.single.statusLabel, '已恢复');
    expect(chains.single.summaryLabel, '失败 -> 重试成功');
    expect(chains.single.latestReason, 'CHAT_WRITE_FORBIDDEN');
    expect(chains.single.events.first.reason, 'CHAT_WRITE_FORBIDDEN');
  });

  test('filters failed chains from recovered and skipped chains', () {
    final chains = buildPipelineLogChains([
      _log(
        id: 'f1',
        messageId: 101,
        createdAtMs: 1000,
        status: ClassifyOperationStatus.failed,
        reason: 'FORBIDDEN',
      ),
      _log(
        id: 'r1',
        messageId: 202,
        createdAtMs: 1000,
        status: ClassifyOperationStatus.failed,
        reason: 'NETWORK',
      ),
      _log(
        id: 'r2',
        messageId: 202,
        createdAtMs: 2000,
        status: ClassifyOperationStatus.retrySuccess,
      ),
      _log(
        id: 's1',
        messageId: 303,
        createdAtMs: 3000,
        status: ClassifyOperationStatus.skipped,
      ),
    ]);

    expect(
      filterPipelineLogChains(chains, PipelineLogFilter.failedInProgress),
      hasLength(1),
    );
    expect(
      filterPipelineLogChains(chains, PipelineLogFilter.recovered),
      hasLength(1),
    );
    expect(
      filterPipelineLogChains(chains, PipelineLogFilter.skippedOrUndone),
      hasLength(1),
    );
  });

  test('groups media failure and retry success into one recovered chain', () {
    final chains = buildPipelineLogChains([
      _log(
        id: 'm1',
        messageId: 404,
        targetChatId: 0,
        createdAtMs: 1000,
        status: ClassifyOperationStatus.mediaFailed,
        reason: '首轮失败',
        categoryKey: 'media',
      ),
      _log(
        id: 'm2',
        messageId: 404,
        targetChatId: 0,
        createdAtMs: 2000,
        status: ClassifyOperationStatus.mediaRetrySuccess,
        categoryKey: 'media',
      ),
    ]);

    expect(chains, hasLength(1));
    expect(chains.single.state, PipelineLogChainState.recovered);
    expect(chains.single.events.last.statusLabel, '媒体重试成功');
    expect(chains.single.summaryLabel, '媒体失败 -> 媒体重试成功');
  });
}

ClassifyOperationLog _log({
  required String id,
  int messageId = 100,
  int targetChatId = 200,
  int createdAtMs = 1000,
  required ClassifyOperationStatus status,
  String? reason,
  String categoryKey = 'cat',
}) {
  return ClassifyOperationLog(
    id: id,
    categoryKey: categoryKey,
    messageId: messageId,
    targetChatId: targetChatId,
    createdAtMs: createdAtMs,
    status: status,
    reason: reason,
  );
}
