import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class MediaDownloadCoordinator {
  static const int _downloadPriorityPhotoPreview = 16;
  static const int _downloadPriorityPhotoFile = 18;
  static const int _downloadPriorityVideoPreview = 17;
  static const int _downloadPriorityAudioFile = 19;
  static const int _downloadPriorityVideoFile = 20;
  static const int _downloadOffsetStart = 0;
  static const int _downloadLimitUnlimited = 0;

  const MediaDownloadCoordinator({required TdlibAdapter adapter})
    : _adapter = adapter;

  final TdlibAdapter _adapter;

  Future<void> warmUpPreview(TdMessageContentDto content) async {
    if (content.kind == TdMessageContentKind.photo) {
      await _ensureFileDownloadStarted(
        fileId: content.remoteImageFileId,
        localPath: content.localImagePath,
        priority: _downloadPriorityPhotoPreview,
      );
      return;
    }
    if (content.kind == TdMessageContentKind.video) {
      await _ensureFileDownloadStarted(
        fileId: content.remoteVideoThumbnailFileId,
        localPath: content.localVideoThumbnailPath,
        priority: _downloadPriorityVideoPreview,
      );
      return;
    }
    if (content.kind == TdMessageContentKind.audio) {
      return;
    }
    final linkPreview = content.linkPreview;
    if (linkPreview != null) {
      await _ensureFileDownloadStarted(
        fileId: linkPreview.remoteImageFileId,
        localPath: linkPreview.localImagePath,
        priority: _downloadPriorityPhotoPreview,
      );
    }
  }

  Future<bool> preparePlayback(TdMessageContentDto content) async {
    if (content.kind == TdMessageContentKind.photo) {
      return _ensureFileDownloadStarted(
        fileId: content.remoteFullImageFileId,
        localPath: content.fullImagePath,
        priority: _downloadPriorityPhotoFile,
      );
    }
    if (content.kind == TdMessageContentKind.audio) {
      return _ensureFileDownloadStarted(
        fileId: content.remoteAudioFileId,
        localPath: content.localAudioPath,
        priority: _downloadPriorityAudioFile,
      );
    }
    if (content.kind == TdMessageContentKind.video) {
      return _ensureFileDownloadStarted(
        fileId: content.remoteVideoFileId,
        localPath: content.localVideoPath,
        priority: _downloadPriorityVideoFile,
      );
    }
    return false;
  }

  Future<bool> _ensureFileDownloadStarted({
    required int? fileId,
    required String? localPath,
    required int priority,
  }) async {
    if (fileId == null || (localPath != null && localPath.isNotEmpty)) {
      return false;
    }
    await _adapter.sendWire(
      DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: _downloadOffsetStart,
        limit: _downloadLimitUnlimited,
        synchronous: false,
      ),
      request: 'downloadFile',
      phase: TdlibPhase.business,
    );
    return true;
  }
}
