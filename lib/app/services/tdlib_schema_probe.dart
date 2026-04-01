import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

typedef TdlibProbeSend = Future<TdWireEnvelope> Function(TdFunction function);

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
    if (response.type == 'ok') {
      return const TdlibSchemaCapabilities(
        addProxyMode: TdlibAddProxyMode.flatArgs,
      );
    }
    if (_isLegacyProxyShapeError(response)) {
      return const TdlibSchemaCapabilities(
        addProxyMode: TdlibAddProxyMode.nestedProxyObject,
      );
    }
    if (response.isError) {
      throw TdlibFailure.tdError(
        code: response.errorCode ?? 0,
        message: response.errorMessage ?? 'Unknown TDLib error',
        request: 'addProxy',
        phase: TdlibPhase.startup,
      );
    }
    throw TdlibFailure.transport(
      message: 'Unexpected schema probe response: ${response.type}',
      request: 'addProxy',
      phase: TdlibPhase.startup,
    );
  }

  bool _isLegacyProxyShapeError(TdWireEnvelope object) {
    return object.isError &&
        object.errorCode == 400 &&
        object.errorMessage == 'Proxy must be non-empty';
  }
}
