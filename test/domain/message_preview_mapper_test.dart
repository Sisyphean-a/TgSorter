import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';

void main() {
  group('mapMessagePreview', () {
    test('maps MessageText to text preview', () {
      const content = TdMessageContentDto(
        kind: TdMessageContentKind.text,
        messageId: 1,
        text: TdFormattedTextDto(text: 'hello', entities: []),
      );
      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.text);
      expect(preview.title, 'hello');
      expect(preview.text, isNotNull);
      expect(preview.subtitle, isNull);
    });

    test('maps MessagePhoto to photo preview with fallback title', () {
      const photo = TdMessageContentDto(
        kind: TdMessageContentKind.photo,
        messageId: 2,
        text: TdFormattedTextDto(text: '', entities: []),
      );
      final preview = mapMessagePreview(photo);
      expect(preview.kind, MessagePreviewKind.photo);
      expect(preview.title, '[图片]');
      expect(preview.text, isNotNull);
    });

    test('maps MessageVideo to video preview with paths and duration', () {
      const content = TdMessageContentDto(
        kind: TdMessageContentKind.video,
        messageId: 3,
        text: TdFormattedTextDto(text: '', entities: []),
        localVideoPath: '/tmp/video.mp4',
        localVideoThumbnailPath: '/tmp/thumb.jpg',
        videoDurationSeconds: 75,
      );

      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.video);
      expect(preview.title, '[视频]');
      expect(preview.localVideoPath, '/tmp/video.mp4');
      expect(preview.localVideoThumbnailPath, '/tmp/thumb.jpg');
      expect(preview.videoDurationSeconds, 75);
    });

    test('maps MessageAudio to audio preview with file metadata', () {
      const content = TdMessageContentDto(
        kind: TdMessageContentKind.audio,
        messageId: 4,
        fileName: 'track.mp3',
        audioTitle: 'Song',
        audioPerformer: 'Artist',
        localAudioPath: '/tmp/track.mp3',
        audioDurationSeconds: 180,
      );

      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.audio);
      expect(preview.title, 'Song');
      expect(preview.subtitle, 'Artist');
      expect(preview.localAudioPath, '/tmp/track.mp3');
      expect(preview.audioDurationSeconds, 180);
    });

    test('maps unsupported content to fallback preview', () {
      const content = TdMessageContentDto(
        kind: TdMessageContentKind.unsupported,
        messageId: 5,
      );
      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.unsupported);
      expect(preview.title, '[暂不支持预览的消息类型，请直接分类]');
    });
  });
}
