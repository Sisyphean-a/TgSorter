import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_adapter.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_runtime_paths.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

void main() {
  group('TdlibAdapter', () {
    test('getProxies returns local proxy dto', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'getProxies': <TdObject>[
            Proxies(
              proxies: [
                Proxy(
                  id: 1,
                  server: '127.0.0.1',
                  port: 1080,
                  lastUsedDate: 0,
                  isEnabled: true,
                  type: const ProxyTypeSocks5(username: '', password: ''),
                ),
              ],
            ),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
      );

      final proxies = await adapter.getProxies();

      expect(proxies.proxies.single.server, '127.0.0.1');
    });

    test('addProxy uses nested proxy request for legacy schema', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'getProxies': <TdObject>[
            Proxies(
              proxies: [
                Proxy(
                  id: 1,
                  server: '10.0.0.1',
                  port: 1080,
                  lastUsedDate: 0,
                  isEnabled: true,
                  type: const ProxyTypeSocks5(username: '', password: ''),
                ),
              ],
            ),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.nestedProxyObject,
        ),
      );

      await adapter.addProxy();

      expect(transport.sentWithoutResponse.single.getConstructor(), 'addProxy');
      expect(
        transport.sentWithoutResponse.single.toJson()['proxy']['server'],
        '10.0.0.1',
      );
    });

    test('submitPhoneNumber wraps td errors as TdlibFailure', () async {
      final transport = _InspectableFakeTransport(
        responses: <String, List<TdObject>>{
          'setAuthenticationPhoneNumber': <TdObject>[
            TdError(code: 401, message: 'PHONE_NUMBER_INVALID'),
          ],
        },
      );
      final adapter = _buildAdapter(
        transport,
        capabilities: const TdlibSchemaCapabilities(
          addProxyMode: TdlibAddProxyMode.flatArgs,
        ),
      );

      expect(
        adapter.submitPhoneNumber('+8613800000000'),
        throwsA(
          isA<TdlibFailure>()
              .having((error) => error.code, 'code', 401)
              .having(
                (error) => error.request,
                'request',
                'setAuthenticationPhoneNumber',
              ),
        ),
      );
    });
  });
}

TdlibAdapter _buildAdapter(
  _InspectableFakeTransport transport, {
  required TdlibSchemaCapabilities capabilities,
}) {
  return TdlibAdapter(
    transport: transport,
    rawTransport: null,
    credentials: const TdlibCredentials(
      apiId: 1,
      apiHash: 'hash',
      proxyServer: '10.0.0.1',
      proxyPort: 1080,
      proxyUsername: '',
      proxyPassword: '',
    ),
    runtimePaths: const TdlibRuntimePaths(
      libraryPath: 'tdjson.dll',
      databaseDirectory: 'db',
      filesDirectory: 'files',
    ),
    detectCapabilities: () async => capabilities,
    initializeTdlib: (_) async {},
  );
}

class _InspectableFakeTransport implements TdTransport {
  _InspectableFakeTransport({required Map<String, List<TdObject>> responses})
    : _responses = responses;

  final Map<String, List<TdObject>> _responses;
  final StreamController<TdObject> _updates =
      StreamController<TdObject>.broadcast();
  final List<TdFunction> sentWithoutResponse = <TdFunction>[];

  @override
  Stream<TdObject> get updates => _updates.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {
    await _updates.close();
  }

  @override
  Future<TdObject> send(TdFunction function) async {
    return sendWithTimeout(function, const Duration(seconds: 20));
  }

  @override
  void sendWithoutResponse(TdFunction function) {
    sentWithoutResponse.add(function);
  }

  @override
  Future<TdObject> sendWithTimeout(
    TdFunction function,
    Duration timeout,
  ) async {
    final queue = _responses[function.getConstructor()];
    if (queue == null || queue.isEmpty) {
      throw StateError(
        'Missing fake response for ${function.getConstructor()}',
      );
    }
    return queue.removeAt(0);
  }
}
