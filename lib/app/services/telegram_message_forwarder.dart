import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

class TelegramMessageForwarder {
  static const Duration _confirmTimeoutDefault = Duration(seconds: 25);
  static const Duration _pollIntervalDefault = Duration(milliseconds: 350);

  TelegramMessageForwarder({
    required TdlibAdapter adapter,
    Duration confirmTimeout = _confirmTimeoutDefault,
    Duration pollInterval = _pollIntervalDefault,
  }) : _adapter = adapter,
       _confirmTimeout = confirmTimeout,
       _pollInterval = pollInterval;

  final TdlibAdapter _adapter;
  final Duration _confirmTimeout;
  final Duration _pollInterval;

  Future<List<int>> forwardMessagesAndConfirmDelivery({
    required int targetChatId,
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required bool sendCopy,
    required String requestLabel,
  }) async {
    final envelope = await _adapter.sendWire(
      ForwardMessages(
        chatId: targetChatId,
        messageThreadId: 0,
        fromChatId: sourceChatId,
        messageIds: sourceMessageIds,
        options: null,
        sendCopy: sendCopy,
        removeCaption: false,
        onlyPreview: false,
      ),
      request: 'forwardMessages',
      phase: TdlibPhase.business,
    );
    final forwarded = _parseForwardedMessageDeliveries(envelope);
    if (forwarded.isEmpty) {
      throw StateError('$requestLabel 返回异常，无法提取目标消息 ID');
    }
    if (forwarded.length != sourceMessageIds.length) {
      throw StateError(
        '$requestLabel 返回数量异常，source=${sourceMessageIds.length},target=${forwarded.length}',
      );
    }
    for (final item in forwarded) {
      if (!item.delivery.isFailed) {
        continue;
      }
      throw StateError(
        '$requestLabel 目标消息发送失败: message_id=${item.messageId},reason=${item.delivery.failureReason}',
      );
    }
    await _waitPendingForwardedMessages(
      targetChatId: targetChatId,
      requestLabel: requestLabel,
      forwarded: forwarded,
    );
    return forwarded.map((item) => item.messageId).toList(growable: false);
  }

  List<_ForwardedMessageDelivery> _parseForwardedMessageDeliveries(
    TdWireEnvelope envelope,
  ) {
    final rawMessages = TdResponseReader.readList(envelope.payload, 'messages');
    return rawMessages
        .map((item) {
          final payload = TdResponseReader.readMap(<String, dynamic>{
            'item': item,
          }, 'item');
          return _ForwardedMessageDelivery(
            messageId: TdResponseReader.readInt(payload, 'id'),
            delivery: _readMessageDeliveryState(payload),
          );
        })
        .toList(growable: false);
  }

  Future<void> _waitPendingForwardedMessages({
    required int targetChatId,
    required String requestLabel,
    required List<_ForwardedMessageDelivery> forwarded,
  }) async {
    final pendingIds = forwarded
        .where((item) => item.delivery.isPending)
        .map((item) => item.messageId)
        .toSet();
    if (pendingIds.isEmpty) {
      return;
    }
    final deadline = DateTime.now().add(_confirmTimeout);
    while (pendingIds.isNotEmpty) {
      final snapshot = pendingIds.toList(growable: false);
      for (final messageId in snapshot) {
        if (messageId <= 0) {
          throw StateError(
            '$requestLabel 返回临时消息 ID($messageId)，发送状态未确认，已中止删除源消息',
          );
        }
        final envelope = await _adapter.sendWire(
          GetMessage(chatId: targetChatId, messageId: messageId),
          request: 'getMessage($targetChatId,$messageId)',
          phase: TdlibPhase.business,
        );
        final delivery = _readMessageDeliveryState(envelope.payload);
        if (delivery.isSent) {
          pendingIds.remove(messageId);
          continue;
        }
        if (delivery.isFailed) {
          throw StateError(
            '$requestLabel 目标消息发送失败: message_id=$messageId,reason=${delivery.failureReason}',
          );
        }
      }
      if (pendingIds.isEmpty) {
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          '$requestLabel 发送状态确认超时，pending=${pendingIds.join(",")}，已中止删除源消息',
        );
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  _MessageDeliveryState _readMessageDeliveryState(
    Map<String, dynamic> messagePayload,
  ) {
    final sendingState = _readDynamicMap(messagePayload['sending_state']);
    if (sendingState == null) {
      return const _MessageDeliveryState.sent();
    }
    final type = sendingState['@type']?.toString() ?? '';
    if (type != 'messageSendingStateFailed') {
      return const _MessageDeliveryState.pending();
    }
    final error = _readDynamicMap(sendingState['error']);
    final code = error?['code']?.toString();
    final message = error?['message']?.toString();
    final reason = <String>[
      if (code != null && code.isNotEmpty) 'code=$code',
      if (message != null && message.isNotEmpty) 'message=$message',
    ].join(',');
    return _MessageDeliveryState.failed(reason.isEmpty ? 'unknown' : reason);
  }

  Map<String, dynamic>? _readDynamicMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is! Map) {
      return null;
    }
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
}

class _ForwardedMessageDelivery {
  const _ForwardedMessageDelivery({
    required this.messageId,
    required this.delivery,
  });

  final int messageId;
  final _MessageDeliveryState delivery;
}

class _MessageDeliveryState {
  const _MessageDeliveryState._({
    required this.isSent,
    required this.isPending,
    required this.failureReason,
  });

  const _MessageDeliveryState.sent()
    : this._(isSent: true, isPending: false, failureReason: null);

  const _MessageDeliveryState.pending()
    : this._(isSent: false, isPending: true, failureReason: null);

  const _MessageDeliveryState.failed(String reason)
    : this._(isSent: false, isPending: false, failureReason: reason);

  final bool isSent;
  final bool isPending;
  final String? failureReason;

  bool get isFailed => failureReason != null;
}
