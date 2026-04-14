enum TelegramLoginAlertKind { code, newLogin }

enum TelegramLoginAlertStatus { active, used, expired, info }

class TelegramLoginAlertTiming {
  static const int codeExpiryWindowMs = 15 * 60 * 1000;

  const TelegramLoginAlertTiming._();
}

class TelegramLoginAlert {
  const TelegramLoginAlert({
    required this.kind,
    required this.status,
    required this.messageId,
    required this.chatId,
    required this.receivedAtMs,
    required this.sourceLabel,
    required this.text,
    this.code,
    this.deviceSummary,
    this.location,
    this.consumedAtMs,
  });

  final TelegramLoginAlertKind kind;
  final TelegramLoginAlertStatus status;
  final int messageId;
  final int chatId;
  final int receivedAtMs;
  final String sourceLabel;
  final String text;
  final String? code;
  final String? deviceSummary;
  final String? location;
  final int? consumedAtMs;

  TelegramLoginAlert copyWith({
    TelegramLoginAlertKind? kind,
    TelegramLoginAlertStatus? status,
    int? messageId,
    int? chatId,
    int? receivedAtMs,
    String? sourceLabel,
    String? text,
    String? code,
    bool clearCode = false,
    String? deviceSummary,
    bool clearDeviceSummary = false,
    String? location,
    bool clearLocation = false,
    int? consumedAtMs,
    bool clearConsumedAtMs = false,
  }) {
    return TelegramLoginAlert(
      kind: kind ?? this.kind,
      status: status ?? this.status,
      messageId: messageId ?? this.messageId,
      chatId: chatId ?? this.chatId,
      receivedAtMs: receivedAtMs ?? this.receivedAtMs,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      text: text ?? this.text,
      code: clearCode ? null : code ?? this.code,
      deviceSummary: clearDeviceSummary
          ? null
          : deviceSummary ?? this.deviceSummary,
      location: clearLocation ? null : location ?? this.location,
      consumedAtMs: clearConsumedAtMs
          ? null
          : consumedAtMs ?? this.consumedAtMs,
    );
  }

  String get identityKey => '${kind.name}:$messageId';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'status': status.name,
      'message_id': messageId,
      'chat_id': chatId,
      'received_at_ms': receivedAtMs,
      'source_label': sourceLabel,
      'text': text,
      'code': code,
      'device_summary': deviceSummary,
      'location': location,
      'consumed_at_ms': consumedAtMs,
    };
  }

  factory TelegramLoginAlert.fromJson(Map<String, dynamic> json) {
    return TelegramLoginAlert(
      kind: TelegramLoginAlertKind.values.firstWhere(
        (value) => value.name == json['kind'],
      ),
      status: TelegramLoginAlertStatus.values.firstWhere(
        (value) => value.name == json['status'],
      ),
      messageId: json['message_id'] as int,
      chatId: json['chat_id'] as int,
      receivedAtMs: json['received_at_ms'] as int,
      sourceLabel: json['source_label'] as String,
      text: json['text'] as String,
      code: json['code'] as String?,
      deviceSummary: json['device_summary'] as String?,
      location: json['location'] as String?,
      consumedAtMs: json['consumed_at_ms'] as int?,
    );
  }
}
