import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/services/classify_transaction_coordinator.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

void main() {
  group('ClassifyTransactionCoordinator', () {
    test('startTransaction persists created transaction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _SpyJournalRepository(prefs);
      final coordinator = _buildCoordinator(repository);

      final transaction = await coordinator.startTransaction(
        sourceChatId: 777,
        sourceMessageIds: const [10],
        targetChatId: 999,
        asCopy: false,
      );

      expect(transaction.stage, ClassifyTransactionStage.created);
      expect(
        repository.upserted.single.stage,
        ClassifyTransactionStage.created,
      );
      expect(repository.loadClassifyTransactions(), hasLength(1));
    });

    test('markForwardConfirmed stores target ids and stage', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _SpyJournalRepository(prefs);
      final coordinator = _buildCoordinator(repository);
      final started = await coordinator.startTransaction(
        sourceChatId: 777,
        sourceMessageIds: const [10],
        targetChatId: 999,
        asCopy: false,
      );

      final updated = await coordinator.markForwardConfirmed(
        started,
        targetMessageIds: const [88],
      );

      expect(updated.stage, ClassifyTransactionStage.forwardConfirmed);
      expect(updated.targetMessageIds, const [88]);
      expect(
        repository.upserted.last.stage,
        ClassifyTransactionStage.forwardConfirmed,
      );
    });

    test('markSourceDeleteConfirmed removes finished transaction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _SpyJournalRepository(prefs);
      final coordinator = _buildCoordinator(repository);
      final started = await coordinator.startTransaction(
        sourceChatId: 777,
        sourceMessageIds: const [10],
        targetChatId: 999,
        asCopy: false,
      );
      final forwarded = await coordinator.markForwardConfirmed(
        started,
        targetMessageIds: const [88],
      );

      await coordinator.markSourceDeleteConfirmed(forwarded);

      expect(
        repository.upserted.last.stage,
        ClassifyTransactionStage.sourceDeleteConfirmed,
      );
      expect(repository.removedIds, [forwarded.id]);
      expect(repository.loadClassifyTransactions(), isEmpty);
    });

    test('recordFailure moves created transaction to manual review', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = _SpyJournalRepository(prefs);
      final coordinator = _buildCoordinator(repository);
      final started = await coordinator.startTransaction(
        sourceChatId: 777,
        sourceMessageIds: const [10],
        targetChatId: 999,
        asCopy: false,
      );

      await coordinator.recordFailure(started, StateError('boom'));

      expect(
        repository.upserted.last.stage,
        ClassifyTransactionStage.needsManualReview,
      );
      expect(repository.upserted.last.lastError, contains('boom'));
    });

    test(
      'recoverPendingTransactions deletes source for forwardConfirmed entry',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = _SpyJournalRepository(
          prefs,
          storedTransactions: [
            _entry(stage: ClassifyTransactionStage.forwardConfirmed),
          ],
        );
        var deleteCalls = 0;
        final coordinator = ClassifyTransactionCoordinator(
          repository: repository,
          anySourceMessageExists: (_) async => true,
          deleteSourceMessages: (_) async {
            deleteCalls++;
          },
          nowMs: () => 2000,
          buildTransactionId: _buildId,
        );

        final summary = await coordinator.recoverPendingTransactions();

        expect(deleteCalls, 1);
        expect(summary.recoveredCount, 1);
        expect(repository.removedIds, hasLength(1));
      },
    );

    test(
      'recoverPendingTransactions removes forwardConfirmed entry when source already missing',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = _SpyJournalRepository(
          prefs,
          storedTransactions: [
            _entry(stage: ClassifyTransactionStage.forwardConfirmed),
          ],
        );
        final coordinator = ClassifyTransactionCoordinator(
          repository: repository,
          anySourceMessageExists: (_) async => false,
          deleteSourceMessages: (_) async => fail('should not delete'),
          nowMs: () => 2000,
          buildTransactionId: _buildId,
        );

        final summary = await coordinator.recoverPendingTransactions();

        expect(summary.recoveredCount, 1);
        expect(repository.removedIds, hasLength(1));
      },
    );

    test(
      'recoverPendingTransactions marks created entry as manual review',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = _SpyJournalRepository(
          prefs,
          storedTransactions: [_entry(stage: ClassifyTransactionStage.created)],
        );
        final coordinator = _buildCoordinator(repository);

        final summary = await coordinator.recoverPendingTransactions();

        expect(summary.manualReviewCount, 1);
        expect(
          repository.upserted.last.stage,
          ClassifyTransactionStage.needsManualReview,
        );
      },
    );

    test(
      'recoverPendingTransactions clears sourceDeleteConfirmed entry directly',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = _SpyJournalRepository(
          prefs,
          storedTransactions: [
            _entry(stage: ClassifyTransactionStage.sourceDeleteConfirmed),
          ],
        );
        final coordinator = _buildCoordinator(repository);

        final summary = await coordinator.recoverPendingTransactions();

        expect(summary.recoveredCount, 1);
        expect(repository.removedIds, hasLength(1));
      },
    );
  });
}

ClassifyTransactionCoordinator _buildCoordinator(
  OperationJournalRepository repository,
) {
  return ClassifyTransactionCoordinator(
    repository: repository,
    anySourceMessageExists: (_) async => true,
    deleteSourceMessages: (_) async {},
    nowMs: () => 1000,
    buildTransactionId: _buildId,
  );
}

String _buildId({
  required int sourceChatId,
  required List<int> sourceMessageIds,
}) {
  return 'tx-$sourceChatId-${sourceMessageIds.first}';
}

ClassifyTransactionEntry _entry({required ClassifyTransactionStage stage}) {
  return ClassifyTransactionEntry(
    id: 'tx-777-10',
    sourceChatId: 777,
    sourceMessageIds: const [10],
    targetChatId: 999,
    asCopy: false,
    targetMessageIds: const [88],
    stage: stage,
    createdAtMs: 1000,
    updatedAtMs: 1000,
    lastError: null,
  );
}

class _SpyJournalRepository extends OperationJournalRepository {
  _SpyJournalRepository(
    super.prefs, {
    List<ClassifyTransactionEntry> storedTransactions = const [],
  }) : _storedTransactions = storedTransactions.toList(growable: true);

  final List<ClassifyTransactionEntry> upserted = <ClassifyTransactionEntry>[];
  final List<String> removedIds = <String>[];
  final List<ClassifyTransactionEntry> _storedTransactions;

  @override
  List<ClassifyTransactionEntry> loadClassifyTransactions() {
    return _storedTransactions.toList(growable: false);
  }

  @override
  Future<void> upsertClassifyTransaction(ClassifyTransactionEntry entry) async {
    upserted.add(entry);
    final index = _storedTransactions.indexWhere((item) => item.id == entry.id);
    if (index < 0) {
      _storedTransactions.add(entry);
    } else {
      _storedTransactions[index] = entry;
    }
  }

  @override
  Future<void> removeClassifyTransaction(String id) async {
    removedIds.add(id);
    _storedTransactions.removeWhere((item) => item.id == id);
  }
}
