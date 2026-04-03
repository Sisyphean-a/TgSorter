import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class ClassifyTransactionCoordinator {
  static const String manualReviewReason =
      '应用在转发确认前中断，无法自动判断是否已转发，请人工核查目标会话后再处理';

  ClassifyTransactionCoordinator({
    required OperationJournalRepository? repository,
    required this.anySourceMessageExists,
    required this.deleteSourceMessages,
    required this.nowMs,
    required this.buildTransactionId,
  }) : _repository = repository;

  final OperationJournalRepository? _repository;
  final Future<bool> Function(ClassifyTransactionEntry transaction)
  anySourceMessageExists;
  final Future<void> Function(ClassifyTransactionEntry transaction)
  deleteSourceMessages;
  final int Function() nowMs;
  final String Function({
    required int sourceChatId,
    required List<int> sourceMessageIds,
  })
  buildTransactionId;

  Future<ClassifyTransactionEntry> startTransaction({
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    final now = nowMs();
    final transaction = ClassifyTransactionEntry(
      id: buildTransactionId(
        sourceChatId: sourceChatId,
        sourceMessageIds: sourceMessageIds,
      ),
      sourceChatId: sourceChatId,
      sourceMessageIds: sourceMessageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
      targetMessageIds: const <int>[],
      stage: ClassifyTransactionStage.created,
      createdAtMs: now,
      updatedAtMs: now,
      lastError: null,
    );
    await _upsert(transaction);
    return transaction;
  }

  Future<ClassifyTransactionEntry> markForwardConfirmed(
    ClassifyTransactionEntry transaction, {
    required List<int> targetMessageIds,
  }) async {
    final updated = transaction.copyWith(
      targetMessageIds: targetMessageIds,
      stage: ClassifyTransactionStage.forwardConfirmed,
      updatedAtMs: nowMs(),
      lastError: null,
    );
    await _upsert(updated);
    return updated;
  }

  Future<void> markSourceDeleteConfirmed(
    ClassifyTransactionEntry transaction,
  ) async {
    final updated = transaction.copyWith(
      stage: ClassifyTransactionStage.sourceDeleteConfirmed,
      updatedAtMs: nowMs(),
      lastError: null,
    );
    await _upsert(updated);
    await _remove(updated.id);
  }

  Future<void> recordFailure(
    ClassifyTransactionEntry transaction,
    Object error,
  ) async {
    if (transaction.stage == ClassifyTransactionStage.sourceDeleteConfirmed) {
      await _remove(transaction.id);
      return;
    }
    if (transaction.stage == ClassifyTransactionStage.created) {
      await _upsert(
        transaction.copyWith(
          stage: ClassifyTransactionStage.needsManualReview,
          updatedAtMs: nowMs(),
          lastError: '$error',
        ),
      );
      return;
    }
    await _upsert(
      transaction.copyWith(updatedAtMs: nowMs(), lastError: '$error'),
    );
  }

  Future<ClassifyRecoverySummary> recoverPendingTransactions() async {
    final pending = _repository?.loadClassifyTransactions() ?? const [];
    if (pending.isEmpty) {
      return ClassifyRecoverySummary.empty;
    }

    var recoveredCount = 0;
    var manualReviewCount = 0;
    var failedCount = 0;

    for (final transaction in pending) {
      switch (transaction.stage) {
        case ClassifyTransactionStage.created:
          await _upsert(
            transaction.copyWith(
              stage: ClassifyTransactionStage.needsManualReview,
              updatedAtMs: nowMs(),
              lastError: manualReviewReason,
            ),
          );
          manualReviewCount++;
          break;
        case ClassifyTransactionStage.forwardConfirmed:
          try {
            final sourceExists = await anySourceMessageExists(transaction);
            if (sourceExists) {
              await deleteSourceMessages(transaction);
            }
            await _remove(transaction.id);
            recoveredCount++;
          } catch (error) {
            await _upsert(
              transaction.copyWith(updatedAtMs: nowMs(), lastError: '$error'),
            );
            failedCount++;
          }
          break;
        case ClassifyTransactionStage.sourceDeleteConfirmed:
          await _remove(transaction.id);
          recoveredCount++;
          break;
        case ClassifyTransactionStage.needsManualReview:
          manualReviewCount++;
          break;
      }
    }

    return ClassifyRecoverySummary(
      recoveredCount: recoveredCount,
      manualReviewCount: manualReviewCount,
      failedCount: failedCount,
    );
  }

  Future<void> _upsert(ClassifyTransactionEntry transaction) {
    final repository = _repository;
    if (repository == null) {
      return Future<void>.value();
    }
    return repository.upsertClassifyTransaction(transaction);
  }

  Future<void> _remove(String id) {
    final repository = _repository;
    if (repository == null) {
      return Future<void>.value();
    }
    return repository.removeClassifyTransaction(id);
  }
}
