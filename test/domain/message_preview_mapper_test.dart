import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';

void main() {
  group('mapMessagePreview', () {
    test('maps MessageText to text preview', () {
      const content = MessageText(
        text: FormattedText(text: 'hello', entities: []),
      );
      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.text);
      expect(preview.title, 'hello');
      expect(preview.text, isNotNull);
      expect(preview.subtitle, isNull);
    });

    test('maps MessagePhoto to photo preview with fallback title', () {
      const photo = MessagePhoto(
        photo: Photo(hasStickers: false, minithumbnail: null, sizes: []),
        caption: FormattedText(text: '', entities: []),
        hasSpoiler: false,
        isSecret: false,
      );
      final preview = mapMessagePreview(photo);
      expect(preview.kind, MessagePreviewKind.photo);
      expect(preview.title, '[图片]');
      expect(preview.text, isNotNull);
    });

    test('maps MessageVideo to video preview with paths and duration', () {
      const content = MessageVideo(
        video: Video(
          duration: 75,
          width: 1080,
          height: 1920,
          fileName: 'clip.mp4',
          mimeType: 'video/mp4',
          hasStickers: false,
          supportsStreaming: true,
          minithumbnail: null,
          thumbnail: Thumbnail(
            format: ThumbnailFormatJpeg(),
            width: 320,
            height: 180,
            file: File(
              id: 11,
              size: 0,
              expectedSize: 0,
              local: LocalFile(
                path: '/tmp/thumb.jpg',
                canBeDownloaded: true,
                canBeDeleted: false,
                isDownloadingActive: false,
                isDownloadingCompleted: true,
                downloadOffset: 0,
                downloadedPrefixSize: 0,
                downloadedSize: 0,
              ),
              remote: RemoteFile(
                id: '',
                uniqueId: '',
                isUploadingActive: false,
                isUploadingCompleted: false,
                uploadedSize: 0,
              ),
            ),
          ),
          video: File(
            id: 12,
            size: 0,
            expectedSize: 0,
            local: LocalFile(
              path: '/tmp/video.mp4',
              canBeDownloaded: true,
              canBeDeleted: false,
              isDownloadingActive: false,
              isDownloadingCompleted: true,
              downloadOffset: 0,
              downloadedPrefixSize: 0,
              downloadedSize: 0,
            ),
            remote: RemoteFile(
              id: '',
              uniqueId: '',
              isUploadingActive: false,
              isUploadingCompleted: false,
              uploadedSize: 0,
            ),
          ),
        ),
        caption: FormattedText(text: '', entities: []),
        hasSpoiler: false,
        isSecret: false,
      );

      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.video);
      expect(preview.title, '[视频]');
      expect(preview.localVideoPath, '/tmp/video.mp4');
      expect(preview.localVideoThumbnailPath, '/tmp/thumb.jpg');
      expect(preview.videoDurationSeconds, 75);
    });

    test('maps unsupported content to fallback preview', () {
      const content = MessagePoll(
        poll: Poll(
          id: 1,
          question: 'q',
          options: [],
          totalVoterCount: 0,
          recentVoterIds: [],
          isAnonymous: true,
          type: PollTypeRegular(allowMultipleAnswers: false),
          openPeriod: 0,
          closeDate: 0,
          isClosed: false,
        ),
      );
      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.unsupported);
      expect(preview.title, '[暂不支持预览的消息类型，请直接分类]');
    });
  });
}
