import 'package:tgsorter/app/services/td_response_reader.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

class TdProxy {
  const TdProxy({
    required this.id,
    required this.server,
    required this.port,
    required this.isEnabled,
  });

  factory TdProxy.fromJson(Map<String, dynamic> payload) {
    final source = _selectSource(payload);
    return TdProxy(
      id: TdResponseReader.readInt(payload, 'id'),
      server: TdResponseReader.readString(source, 'server'),
      port: TdResponseReader.readInt(source, 'port'),
      isEnabled: TdResponseReader.readBool(payload, 'is_enabled'),
    );
  }

  final int id;
  final String server;
  final int port;
  final bool isEnabled;

  static Map<String, dynamic> _selectSource(Map<String, dynamic> payload) {
    if (payload.containsKey('server') && payload.containsKey('port')) {
      return payload;
    }
    if (payload['proxy'] is Map) {
      return TdResponseReader.readMap(payload, 'proxy');
    }
    return payload;
  }
}

class TdProxyList {
  const TdProxyList({required this.proxies});

  factory TdProxyList.fromEnvelope(TdWireEnvelope envelope) {
    final items = TdResponseReader.readList(envelope.payload, 'proxies');
    return TdProxyList(
      proxies: items
          .map(
            (item) => TdProxy.fromJson(
              TdResponseReader.readMap(<String, dynamic>{'item': item}, 'item'),
            ),
          )
          .toList(growable: false),
    );
  }

  final List<TdProxy> proxies;
}
