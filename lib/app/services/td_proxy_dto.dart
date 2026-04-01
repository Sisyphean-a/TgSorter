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
      final endpoint = _findEndpointMap(TdResponseReader.readMap(payload, 'proxy'));
      if (endpoint != null) {
        return endpoint;
      }
    }
    if (payload['type'] is Map) {
      final endpoint = _findEndpointMap(TdResponseReader.readMap(payload, 'type'));
      if (endpoint != null) {
        return endpoint;
      }
    }
    return payload;
  }

  static Map<String, dynamic>? _findEndpointMap(Map<String, dynamic> source) {
    if (source.containsKey('server') && source.containsKey('port')) {
      return source;
    }
    for (final value in source.values) {
      if (value is! Map) {
        continue;
      }
      final endpoint = _findEndpointMap(
        Map<String, dynamic>.from(value.cast<String, dynamic>()),
      );
      if (endpoint != null) {
        return endpoint;
      }
    }
    return null;
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
