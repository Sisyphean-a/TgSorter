import 'dart:async';

import 'package:tgsorter/app/features/dedup/application/media_dedup_workbench.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';

class FakeDedupMediaGateway implements DedupMediaGateway {
  final chats = <SelectableChat>[];
  final history = <DedupMedia>[];
  final historyRequests = <(int chatId, int beforeMessageId)>[];
  final verified = <(int, bool)>[];
  final deleted = <(int, List<int>)>[];
  final photoRequests = <int>[];
  Future<String> Function(int)? photoLoader;
  int? staleId;
  Object? deletionError;
  Stream<DedupMedia>? historyStream;

  @override
  Future<List<SelectableChat>> listChats() async => chats;

  @override
  Stream<({int messageId, DedupMedia? media})> readHistory(
    int chatId, {
    int beforeMessageId = 0,
  }) {
    historyRequests.add((chatId, beforeMessageId));
    return (historyStream ??
            Stream.fromIterable(
              history.where(
                (item) =>
                    item.chatId == chatId &&
                    (beforeMessageId == 0 || item.messageId < beforeMessageId),
              ),
            ))
        .map((item) => (messageId: item.messageId, media: item));
  }

  @override
  Future<String> loadPhotoFile(int fileId) async {
    photoRequests.add(fileId);
    return await photoLoader!(fileId);
  }

  @override
  Future<void> verifyMessage(
    DedupMedia original, {
    required bool forDeletion,
  }) async {
    verified.add((original.messageId, forDeletion));
    if (original.messageId == staleId) throw StateError('消息内容已变化，请重新扫描');
  }

  @override
  Future<void> deleteMessages(int chatId, List<int> messageIds) async {
    deleted.add((chatId, messageIds));
    if (deletionError case final error?) throw error;
  }
}

DedupMedia dedupMedia(
  int messageId,
  int fileId, {
  int chatId = -1001,
  int? size = 3,
  DedupMediaKind kind = DedupMediaKind.photo,
  String caption = '',
  String? identity,
  bool unidentified = false,
  int? durationSeconds,
  int? photoPreviewFileId,
}) => DedupMedia(
  chatId: chatId,
  messageId: messageId,
  fileId: fileId,
  kind: kind,
  size: size,
  sentAt: DateTime(2025, 9, 5, 12, messageId % 60),
  editDate: 0,
  caption: caption,
  fileUniqueId: unidentified ? null : identity ?? 'id-$fileId',
  durationSeconds: durationSeconds,
  photoPreviewFileId: photoPreviewFileId,
);
