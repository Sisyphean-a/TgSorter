import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';

typedef LoginAlertNowMs = int Function();

abstract final class TelegramLoginAlertParser {
  static const int officialAccountId = 777000;
  static const String officialSourceLabel = 'Telegram 官方账号 777000';
  static final RegExp _codePattern = RegExp(r'(?<!\d)(\d{5,8})(?!\d)');
  static final List<RegExp> _devicePatterns = <RegExp>[
    RegExp(r'^Device[:：]\s*(.+)$', caseSensitive: false),
    RegExp(r'^设备[:：]\s*(.+)$'),
  ];
  static final List<RegExp> _locationPatterns = <RegExp>[
    RegExp(r'^Location[:：]\s*(.+)$', caseSensitive: false),
    RegExp(r'^位置[:：]\s*(.+)$'),
  ];

  static TelegramLoginAlert? parse(
    Map<String, dynamic> payload, {
    required int nowMs,
  }) {
    final message = _extractMessage(payload);
    if (message == null || !_isOfficialMessage(message)) {
      return null;
    }
    final text = _extractText(message);
    if (text == null || text.trim().isEmpty) {
      return null;
    }
    final messageId = TdResponseReader.readInt(message, 'id');
    final chatId = TdResponseReader.readInt(message, 'chat_id');
    final receivedAtMs = _extractReceivedAtMs(message, nowMs);
    final codeMatch = _codePattern.firstMatch(text);
    if (codeMatch != null) {
      return TelegramLoginAlert(
        kind: TelegramLoginAlertKind.code,
        status: _resolveCodeStatus(receivedAtMs: receivedAtMs, nowMs: nowMs),
        messageId: messageId,
        chatId: chatId,
        receivedAtMs: receivedAtMs,
        sourceLabel: officialSourceLabel,
        text: text,
        code: codeMatch.group(1),
      );
    }
    final deviceSummary = _extractField(text, _devicePatterns);
    final location = _extractField(text, _locationPatterns);
    if (!_isNewLoginText(
      text,
      deviceSummary: deviceSummary,
      location: location,
    )) {
      return null;
    }
    return TelegramLoginAlert(
      kind: TelegramLoginAlertKind.newLogin,
      status: TelegramLoginAlertStatus.info,
      messageId: messageId,
      chatId: chatId,
      receivedAtMs: receivedAtMs,
      sourceLabel: officialSourceLabel,
      text: text,
      deviceSummary: deviceSummary,
      location: location,
    );
  }

  static Map<String, dynamic>? _extractMessage(Map<String, dynamic> payload) {
    final type = payload['@type']?.toString();
    if (type == 'updateNewMessage') {
      return TdResponseReader.readMap(payload, 'message');
    }
    if (type == 'updateChatLastMessage') {
      return TdResponseReader.readMap(payload, 'last_message');
    }
    return null;
  }

  static bool _isOfficialMessage(Map<String, dynamic> message) {
    final chatId = message['chat_id'];
    if (chatId == officialAccountId) {
      return true;
    }
    final sender = message['sender_id'];
    if (sender is! Map) {
      return false;
    }
    final senderType = sender['@type']?.toString();
    if (senderType != 'messageSenderUser') {
      return false;
    }
    return sender['user_id'] == officialAccountId;
  }

  static String? _extractText(Map<String, dynamic> message) {
    final content = message['content'];
    if (content is! Map) {
      return null;
    }
    if (content['@type'] != 'messageText') {
      return null;
    }
    final text = content['text'];
    if (text is! Map) {
      return null;
    }
    final raw = text['text'];
    return raw is String ? raw.trim() : null;
  }

  static int _extractReceivedAtMs(Map<String, dynamic> message, int nowMs) {
    final raw = message['date'];
    if (raw is int) {
      return raw * 1000;
    }
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        return parsed * 1000;
      }
    }
    return nowMs;
  }

  static TelegramLoginAlertStatus _resolveCodeStatus({
    required int receivedAtMs,
    required int nowMs,
  }) {
    if (nowMs - receivedAtMs >= TelegramLoginAlertTiming.codeExpiryWindowMs) {
      return TelegramLoginAlertStatus.expired;
    }
    return TelegramLoginAlertStatus.active;
  }

  static String? _extractField(String text, List<RegExp> patterns) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final value = match.group(1)?.trim();
          if (value != null && value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return null;
  }

  static bool _isNewLoginText(
    String text, {
    required String? deviceSummary,
    required String? location,
  }) {
    final normalized = text.toLowerCase();
    if (normalized.contains('new login')) {
      return true;
    }
    if (text.contains('新登录') || text.contains('新的登录')) {
      return true;
    }
    return deviceSummary != null || location != null;
  }
}
