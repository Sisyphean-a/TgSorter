import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_schema_capabilities.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

typedef TdlibProbeSend = Future<TdWireEnvelope> Function(TdFunction function);

class TdlibSchemaProbe {
  static const String _webPagePreviewProbeUrl = 'https://telegram.org';

  const TdlibSchemaProbe({required TdlibProbeSend send}) : _send = send;

  final TdlibProbeSend _send;

  Future<TdlibSchemaCapabilities> detect() async {
    final addProxyMode = await _detectAddProxyMode();
    final supportsGetWebPagePreview = await _detectGetWebPagePreviewSupport();
    return TdlibSchemaCapabilities(
      addProxyMode: addProxyMode,
      supportsGetWebPagePreview: supportsGetWebPagePreview,
    );
  }

  Future<TdlibAddProxyMode> _detectAddProxyMode() async {
    final response = await _send(
      AddProxy(
        server: '127.0.0.1',
        port: 1080,
        enable: false,
        type: const ProxyTypeSocks5(username: '', password: ''),
      ),
    );
    if (response.type == 'ok') {
      return TdlibAddProxyMode.flatArgs;
    }
    if (response.type == 'proxy') {
      return TdlibAddProxyMode.flatArgs;
    }
    if (_isLegacyProxyShapeError(response)) {
      return TdlibAddProxyMode.nestedProxyObject;
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

  Future<bool> _detectGetWebPagePreviewSupport() async {
    final response = await _send(
      GetWebPagePreview(
        text: const FormattedText(text: _webPagePreviewProbeUrl, entities: []),
      ),
    );
    return !_isUnsupportedFunctionError(response, 'getWebPagePreview');
  }

  bool _isLegacyProxyShapeError(TdWireEnvelope object) {
    return object.isError &&
        object.errorCode == 400 &&
        object.errorMessage == 'Proxy must be non-empty';
  }

  bool _isUnsupportedFunctionError(TdWireEnvelope object, String constructor) {
    final message = object.errorMessage ?? '';
    return object.isError &&
        object.errorCode == 400 &&
        message.contains('Unknown class "$constructor"');
  }
}
