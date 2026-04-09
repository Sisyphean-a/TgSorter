import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/td_message_send_result.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';

class TdParsedUpdate {
  const TdParsedUpdate({
    this.authState,
    this.connectionState,
    this.messageSendResult,
  });

  final TdAuthState? authState;
  final TdConnectionState? connectionState;
  final TdMessageSendResult? messageSendResult;
}

abstract final class TdUpdateParser {
  static TdParsedUpdate parse(Map<String, dynamic> payload) {
    final type = payload['@type']?.toString() ?? 'unknown';
    if (type == 'updateAuthorizationState') {
      final auth = TdResponseReader.readMap(payload, 'authorization_state');
      return TdParsedUpdate(authState: TdAuthState.fromJson(auth));
    }
    if (type == 'updateConnectionState') {
      final state = TdResponseReader.readMap(payload, 'state');
      return TdParsedUpdate(connectionState: TdConnectionState.fromJson(state));
    }
    if (type == 'updateMessageSendSucceeded') {
      final message = TdResponseReader.readMap(payload, 'message');
      return TdParsedUpdate(
        messageSendResult: TdMessageSendResult.succeeded(
          chatId: TdResponseReader.readInt(message, 'chat_id'),
          oldMessageId: TdResponseReader.readInt(payload, 'old_message_id'),
          messageId: TdResponseReader.readInt(message, 'id'),
        ),
      );
    }
    if (type == 'updateMessageSendFailed') {
      final message = TdResponseReader.readMap(payload, 'message');
      return TdParsedUpdate(
        messageSendResult: TdMessageSendResult.failed(
          chatId: TdResponseReader.readInt(message, 'chat_id'),
          oldMessageId: TdResponseReader.readInt(payload, 'old_message_id'),
          messageId: TdResponseReader.readInt(message, 'id'),
          errorCode: TdResponseReader.readInt(payload, 'error_code'),
          errorMessage: TdResponseReader.readString(payload, 'error_message'),
        ),
      );
    }
    return const TdParsedUpdate();
  }
}
