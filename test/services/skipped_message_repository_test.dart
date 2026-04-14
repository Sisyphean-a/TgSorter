import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';

void main() {
  group('SkippedMessageRepository', () {
    test('upsert persists records and restore supports workflow/source filters', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SkippedMessageRepository(prefs);

      await repo.upsertSkippedMessage(
        SkippedMessageRecord(
          id: 'forwarding:8888:1',
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
          primaryMessageId: 1,
          messageIds: const <int>[1, 2],
          createdAtMs: 1,
        ),
      );
      await repo.upsertSkippedMessage(
        SkippedMessageRecord(
          id: 'tagging:8888:1',
          workflow: SkippedMessageWorkflow.tagging,
          sourceChatId: 8888,
          primaryMessageId: 1,
          messageIds: const <int>[1],
          createdAtMs: 2,
        ),
      );

      expect(
        repo.containsMessage(
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
          messageIds: const <int>[2],
        ),
        isTrue,
      );
      expect(
        repo.countSkippedMessages(
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
        ),
        1,
      );

      final restored = await repo.restoreSkippedMessages(
        workflow: SkippedMessageWorkflow.forwarding,
        sourceChatId: 8888,
      );

      expect(restored, 1);
      expect(
        repo.countSkippedMessages(
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
        ),
        0,
      );
      expect(
        repo.countSkippedMessages(
          workflow: SkippedMessageWorkflow.tagging,
          sourceChatId: 8888,
        ),
        1,
      );
    });

    test('clearAll removes every skipped record', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = SkippedMessageRepository(prefs);

      await repo.upsertSkippedMessage(
        SkippedMessageRecord(
          id: 'forwarding:8888:1',
          workflow: SkippedMessageWorkflow.forwarding,
          sourceChatId: 8888,
          primaryMessageId: 1,
          messageIds: const <int>[1],
          createdAtMs: 1,
        ),
      );
      await repo.upsertSkippedMessage(
        SkippedMessageRecord(
          id: 'tagging:9999:2',
          workflow: SkippedMessageWorkflow.tagging,
          sourceChatId: 9999,
          primaryMessageId: 2,
          messageIds: const <int>[2],
          createdAtMs: 2,
        ),
      );

      await repo.clearAll();

      expect(repo.loadSkippedMessages(), isEmpty);
    });
  });
}
