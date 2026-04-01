import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';

typedef TdlibProbeSend = Future<TdObject> Function(TdFunction function);

class TdlibSchemaProbe {
  const TdlibSchemaProbe({required TdlibProbeSend send}) : _send = send;

  final TdlibProbeSend _send;

  Future<TdlibSchemaCapabilities> detect() async {
    final response = await _send(
      AddProxy(
        server: '127.0.0.1',
        port: 1080,
        enable: false,
        type: const ProxyTypeSocks5(username: '', password: ''),
      ),
    );
    if (response is Ok) {
      return const TdlibSchemaCapabilities(
        addProxyMode: TdlibAddProxyMode.flatArgs,
      );
    }
    if (_isLegacyProxyShapeError(response)) {
      return const TdlibSchemaCapabilities(
        addProxyMode: TdlibAddProxyMode.nestedProxyObject,
      );
    }
    if (response is TdError) {
      throw TdlibFailure.tdError(
        code: response.code,
        message: response.message,
        request: 'addProxy',
        phase: TdlibPhase.startup,
      );
    }
    throw TdlibFailure.transport(
      message: 'Unexpected schema probe response: ${response.getConstructor()}',
      request: 'addProxy',
      phase: TdlibPhase.startup,
    );
  }

  bool _isLegacyProxyShapeError(TdObject object) {
    return object is TdError &&
        object.code == 400 &&
        object.message == 'Proxy must be non-empty';
  }
}
