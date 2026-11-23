import 'dart:async';

import 'package:tdlib/td_api.dart' show DeleteMessages, GetMessage, TdFunction;
import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/message_history_paginator.dart';
import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/telegram_session_resolver.dart';

class TelegramDedupMediaGateway implements DedupMediaGateway {
  TelegramDedupMediaGateway(TdlibAdapter adapter)
    : _adapter = adapter,
      _history = MessageHistoryPaginator(adapter: adapter),
      _sessions = TelegramSessionResolver(adapter: adapter);

  final TdlibAdapter _adapter;
  final MessageHistoryPaginator _history;
  final TelegramSessionResolver _sessions;

  @override
  Future<List<SelectableChat>> listChats() async {
    final chats = await _sessions.listSelectableChats();
    final savedMessagesId = await _sessions.resolveSourceChatId(null);
    return [
      SelectableChat(id: savedMessagesId, title: '收藏夹（Saved Messages）'),
      ...chats,
    ];
  }

  @override
  Stream<({int messageId, DedupMedia? media})> readHistory(
    int chatId, {
    int beforeMessageId = 0,
  }) async* {
    try {
      await for (final message in _history.scanHistory(
        chatId,
        beforeMessageId: beforeMessageId,
      )) {
        yield (
          messageId: TdResponseReader.readInt(message, 'id'),
          media: _readMedia(message),
        );
      }
    } on TdlibFailure catch (error) {
      if (error.kind != TdlibFailureKind.timeout) rethrow;
      throw TimeoutException('读取会话历史超时');
    }
  }

  @override
  Future<void> verifyMessage(
    DedupMedia original, {
    required bool forDeletion,
  }) async {
    final response = await _adapter.sendWire(
      GetMessage(chatId: original.chatId, messageId: original.messageId),
      request: 'getMessage(dedup)',
      phase: TdlibPhase.business,
    );
    final current = _readMedia(response.payload);
    if (current == null ||
        current.chatId != original.chatId ||
        current.messageId != original.messageId ||
        current.kind != original.kind ||
        current.fileUniqueId != original.fileUniqueId ||
        current.sentAt != original.sentAt ||
        current.editDate != original.editDate ||
        current.caption != original.caption) {
      throw StateError('消息内容已变化，请重新扫描');
    }
    if (forDeletion && !await _canDelete(original, response.payload)) {
      throw StateError('没有权限为所有人删除消息 ${original.messageId}');
    }
  }

  Future<bool> _canDelete(
    DedupMedia media,
    Map<String, dynamic> message,
  ) async {
    const key = 'can_be_deleted_for_all_users';
    // 旧版 TDLib 在消息上返回权限，新版由 getMessageProperties 提供。
    if (message.containsKey(key)) {
      return TdResponseReader.readBool(message, key);
    }
    final response = await _adapter.sendWire(
      _GetMessageProperties(media.chatId, media.messageId),
      request: 'getMessageProperties(dedup)',
      phase: TdlibPhase.business,
    );
    return TdResponseReader.readBool(response.payload, key);
  }

  @override
  Future<void> deleteMessages(int chatId, List<int> messageIds) =>
      _adapter.sendWireExpectOk(
        DeleteMessages(chatId: chatId, messageIds: messageIds, revoke: true),
        request: 'deleteMessages(dedup)',
        phase: TdlibPhase.business,
      );

  DedupMedia? _readMedia(Map<String, dynamic> message) {
    if (message['sending_state'] != null) return null;
    final content = TdResponseReader.readMap(message, 'content');
    final DedupMediaKind kind;
    final Map<String, dynamic> file;
    final Map<String, dynamic> metadata;
    switch (content['@type']) {
      case 'messagePhoto':
        kind = DedupMediaKind.photo;
        metadata = TdResponseReader.readMap(content, 'photo');
        file = _largestPhotoFile(metadata);
      case 'messageVideo':
        kind = DedupMediaKind.video;
        metadata = TdResponseReader.readMap(content, 'video');
        file = TdResponseReader.readMap(metadata, 'video');
        break;
      case 'messageAudio':
        kind = DedupMediaKind.audio;
        metadata = TdResponseReader.readMap(content, 'audio');
        file = TdResponseReader.readMap(metadata, 'audio');
      case 'messageVoiceNote':
        kind = DedupMediaKind.voiceNote;
        metadata = TdResponseReader.readMap(content, 'voice_note');
        file = TdResponseReader.readMap(metadata, 'voice');
      default:
        return null;
    }
    final size = TdResponseReader.readInt(file, 'size');
    final remote = file['remote'];
    final thumbnail =
        metadata[kind == DedupMediaKind.audio
            ? 'album_cover_minithumbnail'
            : 'minithumbnail'];
    final audioTitle = metadata['title'] as String?;
    final caption = TdResponseReader.readMap(content, 'caption');
    return DedupMedia(
      chatId: TdResponseReader.readInt(message, 'chat_id'),
      messageId: TdResponseReader.readInt(message, 'id'),
      fileId: TdResponseReader.readInt(file, 'id'),
      kind: kind,
      size: size > 0 ? size : null,
      fileUniqueId: remote is Map ? remote['unique_id'] as String? : null,
      inlineThumbnail: thumbnail is Map ? thumbnail['data'] as String? : null,
      durationSeconds: metadata['duration'] as int?,
      audioTitle: kind == DedupMediaKind.audio
          ? (audioTitle?.isNotEmpty == true
                ? audioTitle
                : metadata['file_name'] as String?)
          : null,
      audioPerformer: kind == DedupMediaKind.audio
          ? metadata['performer'] as String?
          : null,
      sentAt: DateTime.fromMillisecondsSinceEpoch(
        TdResponseReader.readInt(message, 'date') * 1000,
      ),
      editDate: TdResponseReader.readInt(message, 'edit_date'),
      caption: TdResponseReader.readString(caption, 'text', allowEmpty: true),
    );
  }

  Map<String, dynamic> _largestPhotoFile(Map<String, dynamic> photo) {
    final sizes = TdResponseReader.readList(photo, 'sizes');
    Map<String, dynamic>? largest;
    var maxPixels = 0;
    for (final entry in sizes) {
      final size = TdResponseReader.readMap({'size': entry}, 'size');
      final pixels =
          TdResponseReader.readInt(size, 'width') *
          TdResponseReader.readInt(size, 'height');
      if (pixels >= maxPixels) {
        maxPixels = pixels;
        largest = size;
      }
    }
    if (largest == null) throw const TdResponseReadError('照片没有可比较的文件');
    return TdResponseReader.readMap(largest, 'photo');
  }
}

class _GetMessageProperties extends TdFunction {
  const _GetMessageProperties(this.chatId, this.messageId);

  final int chatId;
  final int messageId;

  @override
  String getConstructor() => 'getMessageProperties';

  @override
  Map<String, dynamic> toJson([dynamic extra]) => {
    '@type': getConstructor(),
    'chat_id': chatId,
    'message_id': messageId,
    '@extra': extra,
  };
}
