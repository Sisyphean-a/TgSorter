import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/tdlib_adapter_support.dart';

void main() {
  group('configureTdPlugin', () {
    test('registers native plugin before initialize', () async {
      final calls = <String>[];

      await configureTdPlugin(
        libraryPath: 'tdjson.dll',
        registerNativePlugin: () {
          calls.add('register');
        },
        initializePlugin: (libraryPath) async {
          calls.add('initialize:$libraryPath');
        },
      );

      expect(calls, ['register', 'initialize:tdjson.dll']);
    });
  });
}
