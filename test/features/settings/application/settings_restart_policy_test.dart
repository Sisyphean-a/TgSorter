import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/application/settings_restart_policy.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

void main() {
  test('shouldRestart returns true only when proxy changes', () {
    final policy = SettingsRestartPolicy();
    final previous = AppSettings.defaults();
    final next = previous.updateProxySettings(
      const ProxySettings(
        server: '127.0.0.1',
        port: 7890,
        username: '',
        password: '',
      ),
    );

    expect(policy.shouldRestart(previous, next), isTrue);
    expect(
      policy.shouldRestart(previous, previous.updateForwardAsCopy(true)),
      isFalse,
    );
  });
}
