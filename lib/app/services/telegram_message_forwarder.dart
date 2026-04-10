import 'dart:async';

import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_message_send_result.dart';
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
       _confirmTimeout = confirmTimeout;

  final TdlibAdapter _adapter;
  final Duration _confirmTimeout;
  Stream<TdMessageSendResult> get _messageSendResults =>
      _adapter.messageSendResults;

  Future<List<int>> forwardMessagesAndConfirmDelivery({
    required int targetChatId,
    required int sourceChatId,
    required List<int> sourceMessageIds,
    required bool sendCopy,
    required String requestLabel,
  }) async {
    final bufferedResults = StreamController<TdMessageSendResult>();
    final subscription = _messageSendResults
        .where((item) => item.chatId == targetChatId)
        .listen(bufferedResults.add);
    try {
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
      final confirmedIds = await _waitPendingForwardedMessages(
        requestLabel: requestLabel,
        forwarded: forwarded,
        resultStream: bufferedResults.stream,
      );
      return forwarded
          .map((item) => confirmedIds[item.messageId] ?? item.messageId)
          .toList(growable: false);
    } finally {
      unawaited(subscription.cancel());
      unawaited(bufferedResults.close());
    }
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

  Future<Map<int, int>> _waitPendingForwardedMessages({
    required String requestLabel,
    required List<_ForwardedMessageDelivery> forwarded,
    required Stream<TdMessageSendResult> resultStream,
  }) async {
    final pendingIds = forwarded
        .where((item) => item.delivery.isPending)
        .map((item) => item.messageId)
        .toSet();
    final confirmedIds = <int, int>{};
    if (pendingIds.isEmpty) {
      return confirmedIds;
    }
    final resultIterator = StreamIterator<TdMessageSendResult>(resultStream);
    final deadline = DateTime.now().add(_confirmTimeout);
    try {
      while (pendingIds.isNotEmpty) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw StateError(
            '$requestLabel 发送状态确认超时，pending=${pendingIds.join(",")}，已中止删除源消息',
          );
        }
        final hasNext = await resultIterator.moveNext().timeout(
          remaining,
          onTimeout: () => false,
        );
        if (!hasNext) {
          throw StateError(
            '$requestLabel 发送状态确认超时，pending=${pendingIds.join(",")}，已中止删除源消息',
          );
        }
        final result = resultIterator.current;
        if (!pendingIds.contains(result.oldMessageId)) {
          continue;
        }
        if (!result.isSuccess) {
          throw StateError(
            '$requestLabel 目标消息发送失败: message_id=${result.oldMessageId},reason=code=${result.errorCode},message=${result.errorMessage}',
          );
        }
        pendingIds.remove(result.oldMessageId);
        confirmedIds[result.oldMessageId] = result.messageId;
      }
      return confirmedIds;
    } finally {
      await resultIterator.cancel();
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
