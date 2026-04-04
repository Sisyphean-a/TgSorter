import 'package:tgsorter/app/models/proxy_settings.dart';

abstract class AuthSettingsPort {
  ProxySettings get currentProxySettings;

  Future<void> saveProxySettings({
    required String server,
    required String port,
    required String username,
    required String password,
    bool restart = false,
  });
}
