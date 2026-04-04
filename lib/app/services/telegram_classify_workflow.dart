import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/services/classify_transaction_coordinator.dart';

typedef ForwardMessagesAndConfirmDelivery =
    Future<List<int>> Function({
      required int targetChatId,
      required int sourceChatId,
      required List<int> sourceMessageIds,
      required bool sendCopy,
      required String requestLabel,
    });

typedef DeleteMessagesCallback =
    Future<void> Function({
      required int chatId,
      required List<int> messageIds,
      required String requestLabel,
    });

class TelegramClassifyWorkflow {
  TelegramClassifyWorkflow({
    required this.forwardMessagesAndConfirmDelivery,
    required this.deleteMessages,
    required this.transactionCoordinator,
  });

  final ForwardMessagesAndConfirmDelivery forwardMessagesAndConfirmDelivery;
  final DeleteMessagesCallback deleteMessages;
  final ClassifyTransactionCoordinator transactionCoordinator;

  Future<ClassifyReceipt> classifyMessage({
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    final startedTransaction = await transactionCoordinator.startTransaction(
      sourceChatId: sourceChatId,
      sourceMessageIds: sourceMessageIds,
      targetChatId: targetChatId,
      asCopy: asCopy,
    );
    var transaction = startedTransaction;
    try {
      final targetMessageIds = await forwardMessagesAndConfirmDelivery(
        targetChatId: targetChatId,
        sourceChatId: sourceChatId,
        sourceMessageIds: sourceMessageIds,
        sendCopy: asCopy,
        requestLabel: 'forwardMessages',
      );
      transaction = await transactionCoordinator.markForwardConfirmed(
        transaction,
        targetMessageIds: targetMessageIds,
      );

      await deleteMessages(
        chatId: sourceChatId,
        messageIds: sourceMessageIds,
        requestLabel: 'deleteMessages',
      );

      await transactionCoordinator.markSourceDeleteConfirmed(transaction);

      return ClassifyReceipt(
        sourceChatId: sourceChatId,
        sourceMessageIds: sourceMessageIds,
        targetChatId: targetChatId,
        targetMessageIds: targetMessageIds,
      );
    } catch (error) {
      await transactionCoordinator.recordFailure(transaction, error);
      rethrow;
    }
  }

  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {
    await forwardMessagesAndConfirmDelivery(
      targetChatId: sourceChatId,
      sourceChatId: targetChatId,
      sourceMessageIds: targetMessageIds,
      sendCopy: true,
      requestLabel: 'undo forward',
    );
    await deleteMessages(
      chatId: targetChatId,
      messageIds: targetMessageIds,
      requestLabel: 'deleteMessages',
    );
  }

  Future<ClassifyRecoverySummary> recoverPendingClassifyOperations() {
    return transactionCoordinator.recoverPendingTransactions();
  }
}
