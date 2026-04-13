import 'package:tgsorter/app/features/settings/application/settings_input_validator.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';

class ConnectionSettingsService {
  ConnectionSettingsService({SettingsInputValidator? validator})
    : _validator = validator ?? SettingsInputValidator();

  final SettingsInputValidator _validator;

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
        port: _validator.parsePort(port),
        username: username,
        password: password,
      ),
    );
  }
}
