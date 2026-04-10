import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/models/tag_config.dart';

void main() {
  group('TagConfig', () {
    test('normalizes leading hash and displays as hashtag', () {
      final tag = TagConfig.fromRaw('#摄影');

      expect(tag.name, '摄影');
      expect(tag.displayName, '#摄影');
    });

    test('rejects empty tag name', () {
      expect(() => TagConfig.fromRaw('  #  '), throwsArgumentError);
    });

    test('rejects whitespace inside tag name', () {
      expect(() => TagConfig.fromRaw('风景 摄影'), throwsArgumentError);
    });
  });

  group('TagGroupConfig', () {
    test('rejects duplicate normalized tags', () {
      expect(
        () => TagGroupConfig.fromRaw(
          key: 'default',
          title: '默认组',
          tags: const ['摄影', '#摄影'],
        ),
        throwsStateError,
      );
    });
  });
}
