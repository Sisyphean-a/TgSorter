import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/models/retry_queue_item.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';

void main() {
  group('OperationJournalRepository', () {
    test('load returns empty data by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OperationJournalRepository(prefs);

      final logs = repo.loadLogs();
      final queue = repo.loadRetryQueue();

      expect(logs, isEmpty);
      expect(queue, isEmpty);
    });

    test('saveLogs persists and reloads entries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OperationJournalRepository(prefs);
      final expected = [
        ClassifyOperationLog(
          id: 'log-1',
          categoryKey: 'a',
          messageId: 1001,
          targetChatId: 2001,
          createdAtMs: 1710000000000,
          status: ClassifyOperationStatus.success,
        ),
      ];

      await repo.saveLogs(expected);
      final actual = repo.loadLogs();

      expect(actual.length, 1);
      expect(actual.first.id, 'log-1');
      expect(actual.first.status, ClassifyOperationStatus.success);
      expect(actual.first.messageId, 1001);
    });

    test('saveRetryQueue persists and reloads entries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OperationJournalRepository(prefs);
      final expected = [
        RetryQueueItem(
          id: 'retry-1',
          categoryKey: 'b',
          sourceChatId: 5001,
          messageIds: const [3001, 3002],
          targetChatId: 4001,
          createdAtMs: 1720000000000,
          reason: 'TDLib 请求失败(429): Too Many Requests',
        ),
      ];

      await repo.saveRetryQueue(expected);
      final actual = repo.loadRetryQueue();

      expect(actual.length, 1);
      expect(actual.first.id, 'retry-1');
      expect(actual.first.categoryKey, 'b');
      expect(actual.first.messageIds, [3001, 3002]);
      expect(actual.first.reason, contains('429'));
    });

    test('saveClassifyTransactions persists and reloads entries', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = OperationJournalRepository(prefs);
      final expected = [
        ClassifyTransactionEntry(
          id: 'tx-1',
          sourceChatId: 7001,
          sourceMessageIds: const [11, 12],
          targetChatId: 8001,
          asCopy: false,
          targetMessageIds: const [1011, 1012],
          stage: ClassifyTransactionStage.forwardConfirmed,
          createdAtMs: 1730000000000,
          updatedAtMs: 1730000000100,
          lastError: null,
        ),
      ];

      await repo.saveClassifyTransactions(expected);
      final actual = repo.loadClassifyTransactions();

      expect(actual.length, 1);
      expect(actual.first.id, 'tx-1');
      expect(actual.first.sourceMessageIds, [11, 12]);
      expect(actual.first.targetMessageIds, [1011, 1012]);
      expect(actual.first.stage, ClassifyTransactionStage.forwardConfirmed);
    });
  });
}
