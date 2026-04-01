import 'package:tdlib/td_api.dart';

class TdWireEnvelope {
  const TdWireEnvelope({
    required this.payload,
    required this.type,
    required this.extra,
    required this.clientId,
    required this.isError,
    this.errorCode,
    this.errorMessage,
  });

  factory TdWireEnvelope.fromJson(Map<String, dynamic> payload) {
    final type = payload['@type']?.toString() ?? 'unknown';
    final errorCode = payload['code'] is int ? payload['code'] as int : null;
    final errorMessage = payload['message']?.toString();
    return TdWireEnvelope(
      payload: Map<String, dynamic>.unmodifiable(payload),
      type: type,
      extra: payload['@extra']?.toString(),
      clientId: payload['@client_id'] as int?,
      isError: type == 'error',
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  factory TdWireEnvelope.fromTdObject(TdObject object) {
    final payload = Map<String, dynamic>.from(object.toJson());
    payload['@type'] ??= object.getConstructor();
    if (object.extra != null) {
      payload['@extra'] ??= object.extra;
    }
    if (object.clientId != null) {
      payload['@client_id'] ??= object.clientId;
    }
    return TdWireEnvelope.fromJson(payload);
  }

  final Map<String, dynamic> payload;
  final String type;
  final String? extra;
  final int? clientId;
  final bool isError;
  final int? errorCode;
  final String? errorMessage;
}

class TdWireError {
  const TdWireError({required this.code, required this.message});

  factory TdWireError.fromEnvelope(TdWireEnvelope envelope) {
    return TdWireError(
      code: envelope.errorCode ?? 0,
      message: envelope.errorMessage ?? 'Unknown TDLib error',
    );
  }

  final int code;
  final String message;
}
