import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/services/td_proxy_dto.dart';
import 'package:tgsorter/app/services/td_wire_message.dart';

void main() {
  group('TdProxyList', () {
    test('parses nested proxy object shape', () {
      final dto = TdProxyList.fromEnvelope(
        TdWireEnvelope.fromJson(<String, dynamic>{
          '@type': 'proxies',
          'proxies': [
            {
              '@type': 'proxy',
              'id': 7,
              'last_used_date': 0,
              'is_enabled': true,
              'proxy': {
                'server': '192.168.1.9',
                'port': 443,
                'type': {
                  '@type': 'proxyTypeSocks5',
                  'username': '',
                  'password': '',
                },
              },
            },
          ],
        }),
      );

      expect(dto.proxies.single.server, '192.168.1.9');
      expect(dto.proxies.single.port, 443);
      expect(dto.proxies.single.isEnabled, isTrue);
    });
  });
}
