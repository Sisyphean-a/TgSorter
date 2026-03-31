import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';

void main() {
  group('mapMessagePreview', () {
    test('maps MessageText to text preview', () {
      const content = MessageText(text: FormattedText(text: 'hello', entities: []));
      final preview = mapMessagePreview(content);
      expect(preview.kind, MessagePreviewKind.text);
      expect(preview.title, 'hello');
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
