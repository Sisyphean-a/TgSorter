import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_client_transport.dart';
import 'package:tgsorter/app/services/tdlib_adapter_support.dart';
import 'package:tgsorter/app/services/tdlib_credentials.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/td_proxy_dto.dart';
import 'package:tgsorter/app/services/tdlib_request_executor.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

class TdlibProxyManager {
  const TdlibProxyManager({
    required TdTransport transport,
    required TdlibCredentials credentials,
    required TdlibRequestExecutor requestExecutor,
  }) : _transport = transport,
       _credentials = credentials,
       _requestExecutor = requestExecutor;

  final TdTransport _transport;
  final TdlibCredentials _credentials;
  final TdlibRequestExecutor _requestExecutor;

  Future<TdProxyList> getProxies() async {
    final envelope = await _requestExecutor.sendWire(
      const GetProxies(),
      request: 'getProxies',
      phase: TdlibPhase.startup,
      timeout: const Duration(seconds: 20),
    );
    return TdProxyList.fromEnvelope(envelope);
  }

  Future<void> addProxy(TdlibSchemaCapabilities capabilities) async {
    final server = _credentials.proxyServer;
    final port = _credentials.proxyPort;
    if (server == null || port == null) {
      throw StateError('代理未配置，无法执行 addProxy');
    }
    if (capabilities.addProxyMode == TdlibAddProxyMode.flatArgs) {
      await _requestExecutor.sendWireExpectOk(
        AddProxy(
          server: server,
          port: port,
          enable: true,
          type: ProxyTypeSocks5(
            username: _credentials.proxyUsername,
            password: _credentials.proxyPassword,
          ),
        ),
        request: 'addProxy',
        phase: TdlibPhase.startup,
        timeout: const Duration(seconds: 20),
      );
      return;
    }
    final request = AddProxyCompatRequest(
      server: server,
      port: port,
      username: _credentials.proxyUsername,
      password: _credentials.proxyPassword,
    );
    _transport.sendWithoutResponse(request);
    final proxies = await getProxies();
    final matched = proxies.proxies.any(
      (proxy) =>
          proxy.server == server && proxy.port == port && proxy.isEnabled,
    );
    if (!matched) {
      throw TdlibFailure.transport(
        message: '代理兼容配置后未发现已启用代理 $server:$port',
        request: 'addProxy',
        phase: TdlibPhase.startup,
      );
    }
  }

  Future<void> disableProxy() {
    return _requestExecutor.sendWireExpectOk(
      const DisableProxy(),
      request: 'disableProxy',
      phase: TdlibPhase.startup,
      timeout: const Duration(seconds: 20),
    );
  }
}
