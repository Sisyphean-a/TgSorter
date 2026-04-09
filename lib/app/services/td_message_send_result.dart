class TdMessageSendResult {
  const TdMessageSendResult._({
    required this.chatId,
    required this.oldMessageId,
    required this.messageId,
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
  });

  const TdMessageSendResult.succeeded({
    required int chatId,
    required int oldMessageId,
    required int messageId,
  }) : this._(
         chatId: chatId,
         oldMessageId: oldMessageId,
         messageId: messageId,
         isSuccess: true,
       );

  const TdMessageSendResult.failed({
    required int chatId,
    required int oldMessageId,
    required int messageId,
    required int errorCode,
    required String errorMessage,
  }) : this._(
         chatId: chatId,
         oldMessageId: oldMessageId,
         messageId: messageId,
         isSuccess: false,
         errorCode: errorCode,
         errorMessage: errorMessage,
       );

  final int chatId;
  final int oldMessageId;
  final int messageId;
  final bool isSuccess;
  final int? errorCode;
  final String? errorMessage;
}
