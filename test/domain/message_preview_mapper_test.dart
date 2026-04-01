import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';

void main() {
  group('mapMessagePreview', () {
    test('maps MessageText to text preview', () {
      const content = TdMessageContentDto(
        kind: TdMessageContentKind.text,
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

    test('maps unsupported content to fallback preview', () {
      const content = TdMessageContentDto(
        kind: TdMessageContentKind.unsupported,
      );
      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.unsupported);
      expect(preview.title, '[暂不支持预览的消息类型，请直接分类]');
    });
  });
}
