import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

class ConnectionSettingsService {
  AppSettings updateProxy({
    required AppSettings current,
    required String server,
    required String port,
    required String username,
    required String password,
  }) {
    return current.updateProxySettings(
      ProxySettings(
        server: server,
        port: int.tryParse(port.trim()),
        username: username,
        password: password,
      ),
    );
  }
}
