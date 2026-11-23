import 'dart:async';

import 'package:tdlib/td_api.dart'
    show DeleteMessages, DownloadFile, GetMessage, TdFunction;
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
  Future<String> loadPhotoFile(int fileId) async {
    final response = await _adapter.sendWire(
      DownloadFile(
        fileId: fileId,
        priority: 16,
        offset: 0,
        limit: 0,
        synchronous: true,
      ),
      request: 'downloadFile(dedupPhoto)',
      phase: TdlibPhase.business,
    );
    final local = TdResponseReader.readMap(response.payload, 'local');
    if (TdResponseReader.readBool(local, 'is_downloading_completed') != true) {
      throw StateError('照片未下载完成');
    }
    return TdResponseReader.readString(local, 'path');
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
    int? photoPreviewFileId;
    switch (content['@type']) {
      case 'messagePhoto':
        kind = DedupMediaKind.photo;
        metadata = TdResponseReader.readMap(content, 'photo');
        final photo = _photoFiles(metadata);
        file = photo.full;
        photoPreviewFileId = photo.previewId;
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
      inlineThumbnail: kind != DedupMediaKind.photo && thumbnail is Map
          ? thumbnail['data'] as String?
          : null,
      photoPreviewFileId: photoPreviewFileId,
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

  ({Map<String, dynamic> full, int? previewId}) _photoFiles(
    Map<String, dynamic> photo,
  ) {
    final variants = <({Map<String, dynamic> file, int area, int edge})>[];
    for (final entry in TdResponseReader.readList(photo, 'sizes')) {
      final size = TdResponseReader.readMap({'size': entry}, 'size');
      final width = TdResponseReader.readInt(size, 'width');
      final height = TdResponseReader.readInt(size, 'height');
      variants.add((
        file: TdResponseReader.readMap(size, 'photo'),
        area: width * height,
        edge: width >= height ? width : height,
      ));
    }
    if (variants.isEmpty) throw const TdResponseReadError('照片没有可比较的文件');
    // 保持最大尺寸的选取规则：面积相同取最后一个版本。
    final full = variants.reduce((a, b) => a.area > b.area ? a : b).file;
    final fullId = TdResponseReader.readInt(full, 'id');
    int? previewId;
    var edge = 0;
    for (final variant in variants) {
      final id = TdResponseReader.readInt(variant.file, 'id');
      if (id == fullId || variant.edge <= 0) continue;
      // 优先最接近 640px 且不小于它的缩略图；没有时取最大的较小版本。
      final better = edge < 640
          ? variant.edge > edge
          : variant.edge >= 640 && variant.edge < edge;
      if (better) {
        previewId = id;
        edge = variant.edge;
      }
    }
    return (full: full, previewId: previewId);
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
