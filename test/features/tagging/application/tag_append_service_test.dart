import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/tagging/application/tag_append_service.dart';

void main() {
  group('TagAppendService', () {
    test('writes tag into empty text', () {
      final result = const TagAppendService().appendTag('', '摄影');

      expect(result.text, '#摄影');
      expect(result.changed, isTrue);
    });

    test('appends tag after existing text', () {
      final result = const TagAppendService().appendTag('hello', '摄影');

      expect(result.text, 'hello #摄影');
      expect(result.changed, isTrue);
    });

    test('does not append duplicate exact hashtag', () {
      final result = const TagAppendService().appendTag('hello #摄影', '摄影');

      expect(result.text, 'hello #摄影');
      expect(result.changed, isFalse);
    });

    test('does not treat longer hashtag prefix as duplicate', () {
      final result = const TagAppendService().appendTag('#摄影师', '摄影');

      expect(result.text, '#摄影师 #摄影');
      expect(result.changed, isTrue);
    });
  });
}
