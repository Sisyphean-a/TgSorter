import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/default_platform_resource_service.dart';
import 'package:tgsorter/app/services/platform_resource_service.dart';

void main() {
  test('openUrl fails for invalid uri without scheme', () async {
    final service = DefaultPlatformResourceService(
      launchUri: (_) async => true,
      copyText: (_) async {},
      revealFile: (_) async {},
      isWindows: false,
    );

    final result = await service.openUrl(Uri(path: 'relative-path'));

    expect(result.success, isFalse);
    expect(result.message, isNotEmpty);
  });

  test('revealResource reports unsupported platform cleanly', () async {
    final service = DefaultPlatformResourceService(
      launchUri: (_) async => true,
      copyText: (_) async {},
      revealFile: (_) async {},
      isWindows: false,
    );

    final result = await service.revealResource(
      const LocalResource(path: '/tmp/file.txt'),
    );

    expect(result.success, isFalse);
    expect(result.message, contains('暂不支持'));
  });

  test(
    'openResource returns failed result when launcher reports failure',
    () async {
      final service = DefaultPlatformResourceService(
        launchUri: (_) async => false,
        copyText: (_) async {},
        revealFile: (_) async {},
        isWindows: false,
      );

      final result = await service.openResource(
        const LocalResource(path: '/tmp/file.txt'),
      );

      expect(result.success, isFalse);
      expect(result.message, contains('打开文件失败'));
    },
  );

  test('copyPath returns failed result when clipboard write throws', () async {
    final service = DefaultPlatformResourceService(
      launchUri: (_) async => true,
      copyText: (_) async => throw Exception('clipboard error'),
      revealFile: (_) async {},
      isWindows: false,
    );

    final result = await service.copyPath(
      const LocalResource(path: '/tmp/file.txt'),
    );

    expect(result.success, isFalse);
    expect(result.message, contains('复制'));
  });

  test('openResource returns failed result when launcher throws', () async {
    final service = DefaultPlatformResourceService(
      launchUri: (_) async => throw Exception('launch failed'),
      copyText: (_) async {},
      revealFile: (_) async {},
      isWindows: false,
    );

    final result = await service.openResource(
      const LocalResource(path: '/tmp/file.txt'),
    );

    expect(result.success, isFalse);
    expect(result.message, contains('打开文件失败'));
  });

  test('openUrl returns failed result when launcher throws', () async {
    final service = DefaultPlatformResourceService(
      launchUri: (_) async => throw Exception('launch failed'),
      copyText: (_) async {},
      revealFile: (_) async {},
      isWindows: false,
    );

    final result = await service.openUrl(Uri.parse('https://example.com'));

    expect(result.success, isFalse);
    expect(result.message, contains('打开链接失败'));
  });
}
