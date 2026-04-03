import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';

import 'auth_gateway.dart';

class AuthCoordinator extends GetxController {
  AuthCoordinator(this._auth, this._errors, this._settings);

  final AuthGateway _auth;
  final AppErrorController _errors;
  final SettingsCoordinator _settings;

  AuthGateway get auth => _auth;
  AppErrorController get errors => _errors;
  SettingsCoordinator get settings => _settings;
}
