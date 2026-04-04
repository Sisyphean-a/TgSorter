import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_settings_port.dart';
import 'package:tgsorter/app/features/pipeline/ports/pipeline_settings_reader.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';

void main() {
  test('settings coordinator exposes cross-feature settings ports', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gateway = _SettingsPortGateway();
    final coordinator = SettingsCoordinator(
      SettingsRepository(prefs),
      gateway,
      auth: gateway,
    );

    expect(coordinator, isA<AuthSettingsPort>());
    expect(coordinator, isA<PipelineSettingsReader>());
  });
}

class _SettingsPortGateway implements AuthGateway, SessionQueryGateway {
  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

  @override
  Future<void> restart() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}
