import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/tagging/application/tag_target_selector.dart';
import 'package:tgsorter/app/services/td_message_dto.dart';

void main() {
  group('TagTargetSelector', () {
    test('selects editable text message for text edit', () {
      final target = const TagTargetSelector().select([
        _message(
          id: 1,
          kind: TdMessageContentKind.text,
          text: 'hello',
          canBeEdited: true,
        ),
      ]);

      expect(target.messageId, 1);
      expect(target.kind, TagEditKind.text);
      expect(target.currentText, 'hello');
    });

    test('selects editable media message for caption edit', () {
      final target = const TagTargetSelector().select([
        _message(
          id: 2,
          kind: TdMessageContentKind.photo,
          text: 'caption',
          canBeEdited: true,
        ),
      ]);

      expect(target.messageId, 2);
      expect(target.kind, TagEditKind.caption);
      expect(target.currentText, 'caption');
    });

    test(
      'media group selects first editable message with non-empty caption',
      () {
        final target = const TagTargetSelector().select([
          _message(
            id: 3,
            kind: TdMessageContentKind.photo,
            text: '',
            canBeEdited: true,
          ),
          _message(
            id: 4,
            kind: TdMessageContentKind.video,
            text: 'caption',
            canBeEdited: true,
          ),
        ]);

        expect(target.messageId, 4);
        expect(target.kind, TagEditKind.caption);
      },
    );

    test(
      'media group without caption selects first editable caption message',
      () {
        final target = const TagTargetSelector().select([
          _message(
            id: 5,
            kind: TdMessageContentKind.photo,
            text: '',
            canBeEdited: true,
          ),
          _message(
            id: 6,
            kind: TdMessageContentKind.video,
            text: '',
            canBeEdited: true,
          ),
        ]);

        expect(target.messageId, 5);
        expect(target.currentText, '');
      },
    );

    test('throws when no message can be edited', () {
      expect(
        () => const TagTargetSelector().select([
          _message(
            id: 7,
            kind: TdMessageContentKind.photo,
            text: '',
            canBeEdited: false,
          ),
        ]),
        throwsStateError,
      );
    });
  });
}

TdMessageDto _message({
  required int id,
  required TdMessageContentKind kind,
  required String? text,
  required bool canBeEdited,
}) {
  return TdMessageDto(
    id: id,
    mediaAlbumId: null,
    canBeEdited: canBeEdited,
    content: TdMessageContentDto(
      kind: kind,
      messageId: id,
      text: text == null
          ? null
          : TdFormattedTextDto(text: text, entities: const []),
    ),
  );
}
