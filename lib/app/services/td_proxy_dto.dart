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
    return TdProxy(
      id: TdResponseReader.readInt(payload, 'id'),
      server: TdResponseReader.readString(payload, 'server'),
      port: TdResponseReader.readInt(payload, 'port'),
      isEnabled: TdResponseReader.readBool(payload, 'is_enabled'),
    );
  }

  final int id;
  final String server;
  final int port;
  final bool isEnabled;
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
