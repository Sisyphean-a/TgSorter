import 'dart:io';

import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/settings/domain/download_settings.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/download_sync_repository.dart';

abstract class DownloadSyncMessageGateway
    implements MessageReadGateway, MediaGateway {}

abstract class DownloadSyncPort {
  Future<DownloadSyncResult> sync({
    required int sourceChatId,
    required String sourceChatTitle,
    required String targetDirectory,
    required DownloadSettings settings,
  });
}

abstract interface class DownloadSyncSessionPort {
  Future<void> clearSessionState();
}

class NoopDownloadSyncPort implements DownloadSyncPort, DownloadSyncSessionPort {
  const NoopDownloadSyncPort();

  @override
  Future<DownloadSyncResult> sync({
    required int sourceChatId,
    required String sourceChatTitle,
    required String targetDirectory,
    required DownloadSettings settings,
  }) async {
    return const DownloadSyncResult(
      scannedMessages: 0,
      copiedFiles: 0,
      skippedFiles: 0,
      deletedFiles: 0,
    );
  }

  @override
  Future<void> clearSessionState() async {}
}

class DownloadSyncResult {
  const DownloadSyncResult({
    required this.scannedMessages,
    required this.copiedFiles,
    required this.skippedFiles,
    required this.deletedFiles,
  });

  final int scannedMessages;
  final int copiedFiles;
  final int skippedFiles;
  final int deletedFiles;
}

class DownloadSyncService implements DownloadSyncPort, DownloadSyncSessionPort {
  DownloadSyncService({
    required MessageReadGateway messages,
    required MediaGateway media,
    required DownloadSyncRepository repository,
    int pageSize = 50,
    int Function()? nowMs,
  }) : _messages = messages,
       _media = media,
       _repository = repository,
       _pageSize = pageSize,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final MessageReadGateway _messages;
  final MediaGateway _media;
  final DownloadSyncRepository _repository;
  final int _pageSize;
  final int Function() _nowMs;

  @override
  Future<DownloadSyncResult> sync({
    required int sourceChatId,
    required String sourceChatTitle,
    required String targetDirectory,
    required DownloadSettings settings,
  }) async {
    final jobKey = _jobKey(sourceChatId: sourceChatId, root: targetDirectory);
    final existingRecords = _repository.loadRecords();
    final jobRecords = existingRecords
        .where((record) => record.jobKey == jobKey)
        .toList(growable: false);
    final existingById = {
      for (final record in jobRecords) record.id: record,
    };
    final nextRecords = <DownloadSyncRecord>[];
    final seenIds = <String>{};
    var fromMessageId = null as int?;
    var previousCursor = -1;
    var scannedMessages = 0;
    var copiedFiles = 0;
    var skippedFiles = 0;
    var deletedFiles = 0;

    while (true) {
      final page = await _messages.fetchMessagePage(
        direction: MessageFetchDirection.oldestFirst,
        sourceChatId: sourceChatId,
        fromMessageId: fromMessageId,
        limit: _pageSize,
      );
      if (page.isEmpty) {
        break;
      }
      for (final message in page) {
        scannedMessages++;
        final artifacts = await _resolveArtifacts(
          sourceChatId: sourceChatId,
          message: message,
          filter: settings.mediaFilter,
        );
        for (final artifact in artifacts) {
          final recordId = '$jobKey:${artifact.messageId}:${artifact.kind.name}';
          final existing = existingById[recordId];
          seenIds.add(recordId);
          final destinationDirectory = _destinationDirectory(
            root: targetDirectory,
            sourceChatTitle: sourceChatTitle,
            mode: settings.directoryMode,
          );
          await Directory(destinationDirectory).create(recursive: true);
          final preferredName = _preferredFileName(
            artifact.sourcePath,
            artifact.fallbackStem,
            artifact.kind,
          );
          final resolvedPath = _resolveDestinationPath(
            directory: destinationDirectory,
            preferredName: preferredName,
            strategy: settings.conflictStrategy,
            existingRecord: existing,
            skipExistingFiles: settings.skipExistingFiles,
          );
          if (resolvedPath == null) {
            skippedFiles++;
            if (existing != null) {
              nextRecords.add(existing.copyWith(updatedAtMs: _nowMs()));
            }
            continue;
          }
          final sourceFile = File(artifact.sourcePath);
          if (!sourceFile.existsSync()) {
            continue;
          }
          final destinationFile = File(resolvedPath);
          if (destinationFile.path != sourceFile.path) {
            if (destinationFile.existsSync() &&
                settings.conflictStrategy == DownloadConflictStrategy.overwrite) {
              await destinationFile.delete();
            }
            await sourceFile.copy(destinationFile.path);
            copiedFiles++;
          } else {
            skippedFiles++;
          }
          nextRecords.add(
            DownloadSyncRecord(
              id: recordId,
              jobKey: jobKey,
              sourceChatId: sourceChatId,
              messageId: artifact.messageId,
              kind: artifact.kind,
              outputPath: destinationFile.path,
              updatedAtMs: _nowMs(),
            ),
          );
        }
      }
      final cursor = page.last.messageIds.isNotEmpty
          ? page.last.messageIds.last
          : page.last.id;
      if (cursor == previousCursor) {
        break;
      }
      previousCursor = cursor;
      fromMessageId = cursor;
    }

    final retainedRecords = <DownloadSyncRecord>[
      for (final record in existingRecords)
        if (record.jobKey != jobKey) record,
    ];
    retainedRecords.addAll(nextRecords);
    for (final record in jobRecords) {
      if (seenIds.contains(record.id)) {
        continue;
      }
      if (!_shouldManageDeletion(record.kind, settings.mediaFilter)) {
        retainedRecords.add(record);
        continue;
      }
      if (!settings.syncDeletedFiles) {
        retainedRecords.add(record);
        continue;
      }
      final file = File(record.outputPath);
      if (file.existsSync()) {
        await file.delete();
      }
      deletedFiles++;
    }
    await _repository.saveRecords(retainedRecords);
    return DownloadSyncResult(
      scannedMessages: scannedMessages,
      copiedFiles: copiedFiles,
      skippedFiles: skippedFiles,
      deletedFiles: deletedFiles,
    );
  }

  @override
  Future<void> clearSessionState() {
    return _repository.clearRecords();
  }

  Future<List<_DownloadArtifact>> _resolveArtifacts({
    required int sourceChatId,
    required PipelineMessage message,
    required DownloadMediaFilter filter,
  }) async {
    final preview = message.preview;
    final artifacts = <_DownloadArtifact>[];
    if (preview.audioTracks.isNotEmpty) {
      for (final track in preview.audioTracks) {
        if (!_matchesFilter(MediaItemKind.audio, filter)) {
          continue;
        }
        final path = await _ensureReadyPath(
          sourceChatId: sourceChatId,
          messageId: track.messageId,
          kind: MediaItemKind.audio,
          currentPath: track.localAudioPath,
        );
        if (path == null || path.isEmpty) {
          continue;
        }
        artifacts.add(
          _DownloadArtifact(
            messageId: track.messageId,
            kind: MediaItemKind.audio,
            sourcePath: path,
            fallbackStem: track.title,
          ),
        );
      }
    }
    if (preview.mediaItems.isNotEmpty) {
      for (final item in preview.mediaItems) {
        if (!_matchesFilter(item.kind, filter)) {
          continue;
        }
        final path = await _ensureReadyPath(
          sourceChatId: sourceChatId,
          messageId: item.messageId,
          kind: item.kind,
          currentPath: item.fullPath ?? item.previewPath,
        );
        if (path == null || path.isEmpty) {
          continue;
        }
        artifacts.add(
          _DownloadArtifact(
            messageId: item.messageId,
            kind: item.kind,
            sourcePath: path,
            fallbackStem: message.preview.title,
          ),
        );
      }
    }
    return artifacts;
  }

  Future<String?> _ensureReadyPath({
    required int sourceChatId,
    required int messageId,
    required MediaItemKind kind,
    required String? currentPath,
  }) async {
    if (currentPath != null && currentPath.isNotEmpty) {
      return currentPath;
    }
    final refreshed = await _media.prepareMediaPlayback(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
    final candidate = _pathFromMessage(refreshed, messageId, kind);
    if (candidate != null && candidate.isNotEmpty) {
      return candidate;
    }
    final reread = await _messages.refreshMessage(
      sourceChatId: sourceChatId,
      messageId: messageId,
    );
    return _pathFromMessage(reread, messageId, kind);
  }

  String? _pathFromMessage(
    PipelineMessage message,
    int messageId,
    MediaItemKind kind,
  ) {
    if (kind == MediaItemKind.audio) {
      for (final track in message.preview.audioTracks) {
        if (track.messageId == messageId) {
          return track.localAudioPath ?? message.preview.localAudioPath;
        }
      }
      return message.preview.localAudioPath;
    }
    for (final item in message.preview.mediaItems) {
      if (item.messageId == messageId && item.kind == kind) {
        return item.fullPath ?? item.previewPath;
      }
    }
    if (kind == MediaItemKind.video) {
      return message.preview.localVideoPath ??
          message.preview.localVideoThumbnailPath;
    }
    return message.preview.localImagePath;
  }

  String _jobKey({required int sourceChatId, required String root}) {
    return '$sourceChatId|${root.trim()}';
  }

  String _destinationDirectory({
    required String root,
    required String sourceChatTitle,
    required DownloadDirectoryMode mode,
  }) {
    if (mode == DownloadDirectoryMode.flat) {
      return root;
    }
    final safeTitle = _safeSegment(sourceChatTitle);
    return '$root${Platform.pathSeparator}$safeTitle';
  }

  String _preferredFileName(
    String sourcePath,
    String fallbackStem,
    MediaItemKind kind,
  ) {
    final trimmed = sourcePath.trim();
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(RegExp(r'[\\/]'));
      final baseName = parts.isEmpty ? trimmed : parts.last;
      if (baseName.isNotEmpty) {
        return baseName;
      }
    }
    return '${_safeSegment(fallbackStem)}${_defaultExtension(kind)}';
  }

  String? _resolveDestinationPath({
    required String directory,
    required String preferredName,
    required DownloadConflictStrategy strategy,
    required DownloadSyncRecord? existingRecord,
    required bool skipExistingFiles,
  }) {
    final existingPath = existingRecord?.outputPath;
    if (skipExistingFiles &&
        existingPath != null &&
        File(existingPath).existsSync()) {
      return null;
    }
    final preferredPath = '$directory${Platform.pathSeparator}$preferredName';
    if (!File(preferredPath).existsSync()) {
      return preferredPath;
    }
    if (skipExistingFiles || strategy == DownloadConflictStrategy.skip) {
      return null;
    }
    if (strategy == DownloadConflictStrategy.overwrite) {
      return preferredPath;
    }
    final dotIndex = preferredName.lastIndexOf('.');
    final stem = dotIndex < 0 ? preferredName : preferredName.substring(0, dotIndex);
    final ext = dotIndex < 0 ? '' : preferredName.substring(dotIndex);
    var copyIndex = 2;
    while (true) {
      final candidate =
          '$directory${Platform.pathSeparator}$stem ($copyIndex)$ext';
      if (!File(candidate).existsSync()) {
        return candidate;
      }
      copyIndex++;
    }
  }

  bool _matchesFilter(MediaItemKind kind, DownloadMediaFilter filter) {
    switch (filter) {
      case DownloadMediaFilter.all:
        return true;
      case DownloadMediaFilter.photoOnly:
        return kind == MediaItemKind.photo;
      case DownloadMediaFilter.videoOnly:
        return kind == MediaItemKind.video;
      case DownloadMediaFilter.audioOnly:
        return kind == MediaItemKind.audio;
    }
  }

  bool _shouldManageDeletion(MediaItemKind kind, DownloadMediaFilter filter) {
    return _matchesFilter(kind, filter);
  }

  String _safeSegment(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    return normalized.isEmpty ? 'untitled' : normalized;
  }

  String _defaultExtension(MediaItemKind kind) {
    switch (kind) {
      case MediaItemKind.photo:
        return '.jpg';
      case MediaItemKind.video:
        return '.mp4';
      case MediaItemKind.audio:
        return '.mp3';
    }
  }
}

class _DownloadArtifact {
  const _DownloadArtifact({
    required this.messageId,
    required this.kind,
    required this.sourcePath,
    required this.fallbackStem,
  });

  final int messageId;
  final MediaItemKind kind;
  final String sourcePath;
  final String fallbackStem;
}
