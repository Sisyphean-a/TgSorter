import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

class SelectableChat {
  const SelectableChat({required this.id, required this.title});

  final int id;
  final String title;
}

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
  Stream<TdAuthState> get authStates;
  Stream<TdConnectionState> get connectionStates;

  Future<void> start();
  Future<void> restart();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);

  Future<List<SelectableChat>> listSelectableChats();

  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  });

  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required int messageId,
    required int targetChatId,
  });

  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required int targetMessageId,
  });
}
