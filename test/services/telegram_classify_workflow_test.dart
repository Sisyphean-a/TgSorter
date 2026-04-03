import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/classify_transaction_entry.dart';
import 'package:tgsorter/app/services/classify_transaction_coordinator.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/telegram_classify_workflow.dart';

void main() {
  group('TelegramClassifyWorkflow', () {
    test('classifyMessage 删除源消息并返回回执', () async {
      final repository = await _createRepository();
      final workflow = TelegramClassifyWorkflow(
        forwardMessagesAndConfirmDelivery:
            ({
              required int targetChatId,
              required int sourceChatId,
              required List<int> sourceMessageIds,
              required bool sendCopy,
              required String requestLabel,
            }) async {
              expect(targetChatId, 999);
              expect(sourceChatId, 777);
              expect(sourceMessageIds, const <int>[10]);
              expect(sendCopy, isFalse);
              expect(requestLabel, 'forwardMessages');
              return <int>[88];
            },
        deleteMessages:
            ({
              required int chatId,
              required List<int> messageIds,
              required String requestLabel,
            }) async {
              expect(chatId, 777);
              expect(messageIds, const <int>[10]);
              expect(requestLabel, 'deleteMessages');
            },
        transactionCoordinator: _buildCoordinator(repository),
      );

      final receipt = await workflow.classifyMessage(
        sourceChatId: 777,
        sourceMessageIds: const <int>[10],
        targetChatId: 999,
        asCopy: false,
      );

      expect(receipt.sourceChatId, 777);
      expect(receipt.sourceMessageIds, const <int>[10]);
      expect(receipt.targetChatId, 999);
      expect(receipt.targetMessageIds, const <int>[88]);
      expect(repository.loadClassifyTransactions(), isEmpty);
    });

    test('classifyMessage 转发失败后标记为人工复核', () async {
      final repository = await _createRepository();
      final workflow = TelegramClassifyWorkflow(
        forwardMessagesAndConfirmDelivery:
            ({
              required int targetChatId,
              required int sourceChatId,
              required List<int> sourceMessageIds,
              required bool sendCopy,
              required String requestLabel,
            }) async {
              throw StateError('forward failed');
            },
        deleteMessages:
            ({
              required int chatId,
              required List<int> messageIds,
              required String requestLabel,
            }) async {},
        transactionCoordinator: _buildCoordinator(repository),
      );

      await expectLater(
        () => workflow.classifyMessage(
          sourceChatId: 777,
          sourceMessageIds: const <int>[10],
          targetChatId: 999,
          asCopy: false,
        ),
        throwsA(isA<StateError>()),
      );

      final entries = repository.loadClassifyTransactions();
      expect(entries, hasLength(1));
      expect(entries.first.stage, ClassifyTransactionStage.needsManualReview);
      expect(entries.first.lastError, contains('forward failed'));
    });

    test('classifyMessage 删除失败后保留已确认转发事务', () async {
      final repository = await _createRepository();
      final workflow = TelegramClassifyWorkflow(
        forwardMessagesAndConfirmDelivery:
            ({
              required int targetChatId,
              required int sourceChatId,
              required List<int> sourceMessageIds,
              required bool sendCopy,
              required String requestLabel,
            }) async {
              return <int>[88];
            },
        deleteMessages:
            ({
              required int chatId,
              required List<int> messageIds,
              required String requestLabel,
            }) async {
              throw StateError('delete failed');
            },
        transactionCoordinator: _buildCoordinator(repository),
      );

      await expectLater(
        () => workflow.classifyMessage(
          sourceChatId: 777,
          sourceMessageIds: const <int>[10],
          targetChatId: 999,
          asCopy: false,
        ),
        throwsA(isA<StateError>()),
      );

      final entries = repository.loadClassifyTransactions();
      expect(entries, hasLength(1));
      expect(entries.first.stage, ClassifyTransactionStage.forwardConfirmed);
      expect(entries.first.targetMessageIds, const <int>[88]);
      expect(entries.first.lastError, contains('delete failed'));
    });

    test('undoClassify 先反向转发再删除目标消息', () async {
      final calls = <String>[];
      final workflow = TelegramClassifyWorkflow(
        forwardMessagesAndConfirmDelivery:
            ({
              required int targetChatId,
              required int sourceChatId,
              required List<int> sourceMessageIds,
              required bool sendCopy,
              required String requestLabel,
            }) async {
              calls.add('forward');
              expect(targetChatId, 777);
              expect(sourceChatId, 999);
              expect(sourceMessageIds, const <int>[88]);
              expect(sendCopy, isTrue);
              expect(requestLabel, 'undo forward');
              return <int>[10];
            },
        deleteMessages:
            ({
              required int chatId,
              required List<int> messageIds,
              required String requestLabel,
            }) async {
              calls.add('delete');
              expect(chatId, 999);
              expect(messageIds, const <int>[88]);
              expect(requestLabel, 'deleteMessages');
            },
        transactionCoordinator: _buildCoordinator(null),
      );

      await workflow.undoClassify(
        sourceChatId: 777,
        targetChatId: 999,
        targetMessageIds: const <int>[88],
      );

      expect(calls, <String>['forward', 'delete']);
    });

    test('recoverPendingClassifyOperations 返回 coordinator 恢复结果', () async {
      final repository = await _createRepository();
      await repository.saveClassifyTransactions([
        const ClassifyTransactionEntry(
          id: 'tx-1',
          sourceChatId: 777,
          sourceMessageIds: <int>[10],
          targetChatId: 999,
          asCopy: false,
          targetMessageIds: <int>[88],
          stage: ClassifyTransactionStage.forwardConfirmed,
          createdAtMs: 10,
          updatedAtMs: 10,
          lastError: null,
        ),
      ]);
      var recoveryDeleteCalls = 0;
      final workflow = TelegramClassifyWorkflow(
        forwardMessagesAndConfirmDelivery:
            ({
              required int targetChatId,
              required int sourceChatId,
              required List<int> sourceMessageIds,
              required bool sendCopy,
              required String requestLabel,
            }) async {
              throw UnimplementedError();
            },
        deleteMessages:
            ({
              required int chatId,
              required List<int> messageIds,
              required String requestLabel,
            }) async {},
        transactionCoordinator: ClassifyTransactionCoordinator(
          repository: repository,
          anySourceMessageExists: (_) async => true,
          deleteSourceMessages: (_) async {
            recoveryDeleteCalls++;
          },
          nowMs: () => 20,
          buildTransactionId:
              ({
                required int sourceChatId,
                required List<int> sourceMessageIds,
              }) {
                return 'tx-$sourceChatId-${sourceMessageIds.first}';
              },
        ),
      );

      final summary = await workflow.recoverPendingClassifyOperations();

      expect(summary.recoveredCount, 1);
      expect(summary.manualReviewCount, 0);
      expect(summary.failedCount, 0);
      expect(recoveryDeleteCalls, 1);
      expect(repository.loadClassifyTransactions(), isEmpty);
    });
  });
}

Future<OperationJournalRepository> _createRepository() async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  return OperationJournalRepository(prefs);
}

ClassifyTransactionCoordinator _buildCoordinator(
  OperationJournalRepository? repository,
) {
  return ClassifyTransactionCoordinator(
    repository: repository,
    anySourceMessageExists: (_) async => false,
    deleteSourceMessages: (_) async {},
    nowMs: () => 1730000000000,
    buildTransactionId:
        ({required int sourceChatId, required List<int> sourceMessageIds}) {
          return 'tx-$sourceChatId-${sourceMessageIds.first}';
        },
  );
}
