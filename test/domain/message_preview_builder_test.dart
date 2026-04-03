import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_builder.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';

void main() {
  group('MessagePreviewBuilder', () {
    test('groups latest-first audio album into one pipeline item', () {
      const builder = MessagePreviewBuilder();
      final page = builder.groupPipelineMessages(
        messages: <TdMessageDto>[
          _audioMessage(12, 'track 2', albumId: '700'),
          _audioMessage(11, 'track 1', albumId: '700'),
          _textMessage(10, 'tail'),
        ],
        sourceChatId: 777,
        direction: MessageFetchDirection.latestFirst,
      );

      expect(page.length, 2);
      expect(page.first.messageIds, <int>[11, 12]);
      expect(page.first.preview.audioTracks.map((item) => item.title), <String>[
        'track 1',
        'track 2',
      ]);
      expect(page.first.preview.title, '音频组 (2 条)');
    });

    test(
      'builds mixed media album as video gallery and keeps first caption',
      () {
        const builder = MessagePreviewBuilder();
        final page = builder.groupPipelineMessages(
          messages: <TdMessageDto>[
            _videoMessage(12, albumId: '701', caption: ''),
            _photoMessage(11, albumId: '701', caption: '封面说明'),
          ],
          sourceChatId: 777,
          direction: MessageFetchDirection.latestFirst,
        );

        expect(page.single.messageIds, <int>[11, 12]);
        expect(page.single.preview.kind, MessagePreviewKind.video);
        expect(page.single.preview.title, '媒体组 (2 项)');
        expect(page.single.preview.text?.text, '封面说明');
        expect(page.single.preview.mediaItems.length, 2);
        expect(
          page.single.preview.localVideoThumbnailPath,
          '/tmp/thumb-12.jpg',
        );
      },
    );

    test('keeps oldest-first album ids increasing', () {
      const builder = MessagePreviewBuilder();
      final page = builder.groupPipelineMessages(
        messages: <TdMessageDto>[
          _photoMessage(11, albumId: '702', caption: ''),
          _photoMessage(12, albumId: '702', caption: ''),
        ],
        sourceChatId: 777,
        direction: MessageFetchDirection.oldestFirst,
      );

      expect(page.single.messageIds, <int>[11, 12]);
      expect(page.single.preview.kind, MessagePreviewKind.photo);
      expect(page.single.preview.title, '图片组 (2 张)');
      expect(page.single.preview.localImagePath, '/tmp/photo-11.jpg');
    });
  });
}

TdMessageDto _textMessage(int id, String text) {
  return TdMessageDto(
    id: id,
    mediaAlbumId: null,
    content: TdMessageContentDto(
      kind: TdMessageContentKind.text,
      messageId: id,
      text: TdFormattedTextDto(text: text, entities: const []),
    ),
  );
}

TdMessageDto _audioMessage(int id, String title, {required String albumId}) {
  return TdMessageDto(
    id: id,
    mediaAlbumId: albumId,
    content: TdMessageContentDto(
      kind: TdMessageContentKind.audio,
      messageId: id,
      text: const TdFormattedTextDto(text: '', entities: []),
      fileName: '$title.mp3',
      audioTitle: title,
      audioPerformer: 'artist',
      localAudioPath: '/tmp/$title.mp3',
      audioDurationSeconds: 180,
    ),
  );
}

TdMessageDto _photoMessage(
  int id, {
  required String albumId,
  required String caption,
}) {
  return TdMessageDto(
    id: id,
    mediaAlbumId: albumId,
    content: TdMessageContentDto(
      kind: TdMessageContentKind.photo,
      messageId: id,
      text: TdFormattedTextDto(text: caption, entities: const []),
      localImagePath: '/tmp/photo-$id.jpg',
      fullImagePath: '/tmp/photo-full-$id.jpg',
      remoteImageFileId: 100 + id,
      remoteFullImageFileId: 200 + id,
    ),
  );
}

TdMessageDto _videoMessage(
  int id, {
  required String albumId,
  required String caption,
}) {
  return TdMessageDto(
    id: id,
    mediaAlbumId: albumId,
    content: TdMessageContentDto(
      kind: TdMessageContentKind.video,
      messageId: id,
      text: TdFormattedTextDto(text: caption, entities: const []),
      localVideoPath: '/tmp/video-$id.mp4',
      localVideoThumbnailPath: '/tmp/thumb-$id.jpg',
      videoDurationSeconds: 90,
      remoteVideoFileId: 300 + id,
      remoteVideoThumbnailFileId: 400 + id,
    ),
  );
}
