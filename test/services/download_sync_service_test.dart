import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/settings/domain/download_settings.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/download_sync_repository.dart';
import 'package:tgsorter/app/services/download_sync_service.dart';

void main() {
  test('sync copies new media, skips existing files, and removes stale files', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = DownloadSyncRepository(prefs);
    final tempDir = await Directory.systemTemp.createTemp('download-sync-test');
    final sourceDir = Directory('${tempDir.path}/source')..createSync();
    final targetDir = Directory('${tempDir.path}/target')..createSync();
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sourceOne = File('${sourceDir.path}/source-audio.mp3')
      ..writeAsStringSync('audio-a');
    final sourceTwo = File('${sourceDir.path}/source-video.mp4')
      ..writeAsStringSync('video-b');

    final gateway = _FakeDownloadGateway(
      pages: [
        [
          _audioMessage(
            messageId: 11,
            sourceChatId: 777,
            path: sourceOne.path,
            title: '第一条音频',
          ),
          _videoMessage(
            messageId: 22,
            sourceChatId: 777,
            path: sourceTwo.path,
            title: '第二条视频',
          ),
        ],
      ],
    );
    final service = DownloadSyncService(
      messages: gateway,
      media: gateway,
      repository: repository,
      pageSize: 20,
    );
    final settings = AppSettings.defaults().updateDownloadSettings(
      workbenchEnabled: true,
      skipExistingFiles: true,
      syncDeletedFiles: true,
      conflictStrategy: DownloadConflictStrategy.rename,
      mediaFilter: DownloadMediaFilter.all,
      directoryMode: DownloadDirectoryMode.flat,
    );

    final first = await service.sync(
      sourceChatId: 777,
      sourceChatTitle: '下载来源',
      targetDirectory: targetDir.path,
      settings: settings.download,
    );

    expect(first.scannedMessages, 2);
    expect(first.copiedFiles, 2);
    expect(first.skippedFiles, 0);
    expect(first.deletedFiles, 0);
    expect(
      File('${targetDir.path}/source-audio.mp3').readAsStringSync(),
      'audio-a',
    );
    expect(
      File('${targetDir.path}/source-video.mp4').readAsStringSync(),
      'video-b',
    );

    final second = await service.sync(
      sourceChatId: 777,
      sourceChatTitle: '下载来源',
      targetDirectory: targetDir.path,
      settings: settings.download,
    );

    expect(second.copiedFiles, 0);
    expect(second.skippedFiles, 2);

    gateway.pages = [
      [
        _audioMessage(
          messageId: 11,
          sourceChatId: 777,
          path: sourceOne.path,
          title: '第一条音频',
        ),
      ],
    ];

    final third = await service.sync(
      sourceChatId: 777,
      sourceChatTitle: '下载来源',
      targetDirectory: targetDir.path,
      settings: settings.download,
    );

    expect(third.deletedFiles, 1);
    expect(File('${targetDir.path}/source-video.mp4').existsSync(), isFalse);
    expect(repository.loadRecords(), hasLength(1));
  });
}

class _FakeDownloadGateway implements DownloadSyncMessageGateway {
  _FakeDownloadGateway({required this.pages});

  List<List<PipelineMessage>> pages;

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async {
    return pages.fold<int>(0, (count, page) => count + page.length);
  }

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    if (fromMessageId == null) {
      return pages.isEmpty ? const [] : pages.first;
    }
    return const [];
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    if (pages.isEmpty || pages.first.isEmpty) {
      return null;
    }
    return pages.first.first;
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    return pages
        .expand((page) => page)
        .firstWhere((message) => message.id == messageId);
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) {
    return refreshMessage(sourceChatId: sourceChatId, messageId: messageId);
  }
}

PipelineMessage _audioMessage({
  required int messageId,
  required int sourceChatId,
  required String path,
  required String title,
}) {
  return PipelineMessage(
    id: messageId,
    messageIds: [messageId],
    sourceChatId: sourceChatId,
    preview: MessagePreview(
      kind: MessagePreviewKind.audio,
      title: title,
      localAudioPath: path,
      audioTracks: [
        AudioTrackPreview(messageId: messageId, title: title, localAudioPath: path),
      ],
    ),
  );
}

PipelineMessage _videoMessage({
  required int messageId,
  required int sourceChatId,
  required String path,
  required String title,
}) {
  return PipelineMessage(
    id: messageId,
    messageIds: [messageId],
    sourceChatId: sourceChatId,
    preview: MessagePreview(
      kind: MessagePreviewKind.video,
      title: title,
      localVideoPath: path,
      mediaItems: [
        MediaItemPreview(
          messageId: messageId,
          kind: MediaItemKind.video,
          fullPath: path,
        ),
      ],
    ),
  );
}
