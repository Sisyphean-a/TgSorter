import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
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
  });
}
