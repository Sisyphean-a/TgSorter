import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

class ClassifyReceipt {
  const ClassifyReceipt({
    required this.sourceChatId,
    required this.sourceMessageId,
    required this.targetChatId,
    required this.targetMessageId,
  });

  final int sourceChatId;
  final int sourceMessageId;
  final int targetChatId;
  final int targetMessageId;
}

abstract class TelegramGateway {
  Stream<AuthorizationState> get authStates;
  Stream<ConnectionState> get connectionStates;

  Future<void> start();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);

  Future<PipelineMessage?> fetchNextSavedMessage({
    required MessageFetchDirection direction,
  });

  Future<ClassifyReceipt> classifyMessage({
    required int messageId,
    required int targetChatId,
  });

  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required int targetMessageId,
  });
}
