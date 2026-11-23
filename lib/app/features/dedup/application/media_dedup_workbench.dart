import 'dart:async';

import 'package:tgsorter/app/features/dedup/application/video_thumbnail_preview.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';

enum DedupMediaKind {
  photo('照片'),
  video('视频'),
  audio('音频'),
  voiceNote('语音');

  const DedupMediaKind(this.label);
  final String label;
}

class DedupMedia {
  const DedupMedia({
    required this.chatId,
    required this.messageId,
    required this.fileId,
    required this.kind,
    required this.size,
    required this.sentAt,
    required this.editDate,
    required this.caption,
    this.fileUniqueId,
    this.durationSeconds,
    this.audioTitle,
    this.audioPerformer,
    this.inlineThumbnail,
  });

  final int chatId;
  final int messageId;
  final int fileId;
  final DedupMediaKind kind;
  final int? size;
  final DateTime sentAt;
  final int editDate;
  final String caption;
  final String? fileUniqueId;
  final int? durationSeconds;
  final String? audioTitle;
  final String? audioPerformer;
  final String? inlineThumbnail;
}

abstract interface class DedupMediaGateway {
  Future<List<SelectableChat>> listChats();
  Stream<({int messageId, DedupMedia? media})> readHistory(
    int chatId, {
    int beforeMessageId = 0,
  });
  Future<void> verifyMessage(DedupMedia original, {required bool forDeletion});
  Future<void> deleteMessages(int chatId, List<int> messageIds);
}

class DuplicateMediaGroup {
  DuplicateMediaGroup._(List<DedupMedia> copies)
    : copies = List.unmodifiable(copies);

  final List<DedupMedia> copies;
  DedupMediaKind get kind => copies.first.kind;
  int? get size => copies.first.size;
}

class DedupScanResult {
  DedupScanResult._(List<DuplicateMediaGroup> groups, this.unidentified)
    : groups = List.unmodifiable(groups);

  final List<DuplicateMediaGroup> groups;
  final int unidentified;
}

class DedupScanCheckpoint {
  DedupScanCheckpoint._(this._chatId);

  final int _chatId;
  final _byIdentity = <(DedupMediaKind, String), List<DedupMedia>>{};
  int _cursor = 0;
  int _inspected = 0;
  int _unidentified = 0;

  int get inspected => _inspected;
}

class DedupScanInterrupted implements Exception {
  const DedupScanInterrupted(this.checkpoint);

  final DedupScanCheckpoint checkpoint;
}

class DedupScanCancelled implements Exception {
  const DedupScanCancelled();
}

class DedupScanStop {
  bool _cancelled = false;
  void Function()? _cancelPending;

  void cancel() {
    _cancelled = true;
    _cancelPending?.call();
  }

  Future<T> wait<T>(Future<T> Function() operation) async {
    if (_cancelled) throw const DedupScanCancelled();
    final result = Completer<T>();
    _cancelPending = () {
      if (!result.isCompleted) result.completeError(const DedupScanCancelled());
    };
    unawaited(
      Future.sync(operation).then(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    try {
      return await result.future;
    } finally {
      _cancelPending = null;
    }
  }
}

class DedupDeletionUncertain implements Exception {
  const DedupDeletionUncertain(this.error);

  final Object error;
}

class MediaDedupWorkbench {
  const MediaDedupWorkbench(this._gateway, {this.videoThumbnails});

  final DedupMediaGateway _gateway;
  final VideoThumbnailPreview? videoThumbnails;

  Future<List<SelectableChat>> listChats() => _gateway.listChats();

  Future<DedupScanResult> scan(
    int chatId, {
    required DedupScanStop stop,
    required void Function(int inspected) onProgress,
    DedupScanCheckpoint? resumeFrom,
  }) async {
    final checkpoint = resumeFrom ?? DedupScanCheckpoint._(chatId);
    if (checkpoint._chatId != chatId) throw StateError('不能续扫其他会话');
    final history = StreamIterator(
      _gateway.readHistory(chatId, beforeMessageId: checkpoint._cursor),
    );
    try {
      onProgress(checkpoint.inspected);
      while (await stop.wait(history.moveNext)) {
        final (messageId: messageId, media: item) = history.current;
        if (item != null) {
          if (item.chatId != chatId) throw StateError('读取到其他会话的消息');
          final identity = item.fileUniqueId;
          if (identity == null || identity.isEmpty) {
            checkpoint._unidentified++;
          } else {
            (checkpoint._byIdentity[(item.kind, identity)] ??= []).add(item);
          }
          onProgress(++checkpoint._inspected);
        }
        // 文本等非媒体也推进历史游标，续扫不重复读取已处理的消息。
        checkpoint._cursor = messageId;
      }
    } on TimeoutException {
      throw DedupScanInterrupted(checkpoint);
    } finally {
      unawaited(history.cancel());
    }
    final groups =
        [
          for (final copies in checkpoint._byIdentity.values)
            if (copies.length > 1) DuplicateMediaGroup._(copies),
        ]..sort(
          (a, b) =>
              b.copies.first.messageId.compareTo(a.copies.first.messageId),
        );
    return DedupScanResult._(groups, checkpoint._unidentified);
  }

  Future<int> removeDuplicates(DuplicateMediaGroup group, int keepId) async {
    final keep = group.copies.singleWhere((copy) => copy.messageId == keepId);
    final remove = group.copies
        .where((copy) => copy.messageId != keepId)
        .toList();
    for (final item in remove) {
      await _gateway.verifyMessage(item, forDeletion: true);
    }
    // 最后复核保留项；任何一条发生变化都不发送删除请求。
    await _gateway.verifyMessage(keep, forDeletion: false);
    try {
      await _gateway.deleteMessages(
        keep.chatId,
        remove.map((copy) => copy.messageId).toList(growable: false),
      );
    } catch (error) {
      throw DedupDeletionUncertain(error);
    }
    return remove.length;
  }
}
