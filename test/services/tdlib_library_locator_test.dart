import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/tdlib_library_locator.dart';

void main() {
  group('resolveTdlibLibraryPath', () {
    test('returns linux soname on linux-like runtime', () {
      final runtime = TdlibRuntimeInfo(
        isAndroid: false,
        isLinux: true,
        isWindows: false,
        isMacOS: false,
        isIOS: false,
        executablePath: 'C:\\app\\runner.exe',
        environment: const {},
      );

      expect(resolveTdlibLibraryPath(runtime), 'libtdjson.so');
    });

    test('returns mac soname on apple runtime', () {
      final runtime = TdlibRuntimeInfo(
        isAndroid: false,
        isLinux: false,
        isWindows: false,
        isMacOS: true,
        isIOS: false,
        executablePath: 'C:\\app\\runner.exe',
        environment: const {},
      );

      expect(resolveTdlibLibraryPath(runtime), 'libtdjson.dylib');
    });

    test('uses TDLIB_DLL_PATH on windows when file exists', () {
      final tempDir = Directory.systemTemp.createTempSync('tdlib_env_');
      try {
        final envFile = File('${tempDir.path}\\tdjson.dll')
          ..writeAsStringSync('');
        final runtime = TdlibRuntimeInfo(
          isAndroid: false,
          isLinux: false,
          isWindows: true,
          isMacOS: false,
          isIOS: false,
          executablePath: '${tempDir.path}\\runner.exe',
          environment: {'TDLIB_DLL_PATH': envFile.path},
        );

        expect(resolveTdlibLibraryPath(runtime), envFile.path);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uses executable directory tdjson.dll on windows by default', () {
      final tempDir = Directory.systemTemp.createTempSync('tdlib_default_');
      try {
        final dllFile = File('${tempDir.path}\\tdjson.dll')
          ..writeAsStringSync('');
        final runtime = TdlibRuntimeInfo(
          isAndroid: false,
          isLinux: false,
          isWindows: true,
          isMacOS: false,
          isIOS: false,
          executablePath: '${tempDir.path}/runner.exe',
          environment: const {},
        );

        expect(resolveTdlibLibraryPath(runtime), dllFile.path);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('throws clear error on windows when tdjson.dll is missing', () {
      final tempDir = Directory.systemTemp.createTempSync('tdlib_missing_');
      try {
        final runtime = TdlibRuntimeInfo(
          isAndroid: false,
          isLinux: false,
          isWindows: true,
          isMacOS: false,
          isIOS: false,
          executablePath: '${tempDir.path}/runner.exe',
          environment: const {},
        );

        expect(
          () => resolveTdlibLibraryPath(runtime),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('TDLIB_DLL_PATH'),
            ),
          ),
        );
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
