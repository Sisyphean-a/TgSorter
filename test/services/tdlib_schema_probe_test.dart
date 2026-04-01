import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';
import 'package:tgsorter/app/services/tdlib_schema_probe.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

void main() {
  group('TdlibSchemaProbe', () {
    test('detects flat addProxy mode when request succeeds', () async {
      final requests = <TdFunction>[];
      final probe = TdlibSchemaProbe(
        send: (function) async {
          requests.add(function);
          return TdWireEnvelope.fromTdObject(const Ok());
        },
      );

      final capabilities = await probe.detect();

      expect(capabilities.addProxyMode, TdlibAddProxyMode.flatArgs);
      expect(requests.single.getConstructor(), 'addProxy');
    });

    test('detects nested addProxy mode for legacy proxy shape error', () async {
      final probe = TdlibSchemaProbe(
        send: (_) async => TdWireEnvelope.fromTdObject(
          TdError(code: 400, message: 'Proxy must be non-empty'),
        ),
      );

      final capabilities = await probe.detect();

      expect(capabilities.addProxyMode, TdlibAddProxyMode.nestedProxyObject);
    });

    test('treats proxy response as successful flat addProxy mode', () async {
      final probe = TdlibSchemaProbe(
        send: (_) async => TdWireEnvelope.fromTdObject(
          Proxy(
            id: 1,
            server: '127.0.0.1',
            port: 1080,
            lastUsedDate: 0,
            isEnabled: true,
            type: const ProxyTypeSocks5(username: '', password: ''),
          ),
        ),
      );

      final capabilities = await probe.detect();

      expect(capabilities.addProxyMode, TdlibAddProxyMode.flatArgs);
    });

    test('throws TdlibFailure for unexpected td error', () async {
      final probe = TdlibSchemaProbe(
        send: (_) async =>
            TdWireEnvelope.fromTdObject(TdError(code: 500, message: 'INTERNAL')),
      );

      expect(
        probe.detect(),
        throwsA(
          isA<TdlibFailure>()
              .having((error) => error.code, 'code', 500)
              .having((error) => error.request, 'request', 'addProxy'),
        ),
      );
    });
  });
}
