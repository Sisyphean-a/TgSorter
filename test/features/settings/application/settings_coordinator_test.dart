import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';

void main() {
  test('save persists draft and restarts only when proxy changes', () async {
    final harness = _SettingsCoordinatorHarness();
    final coordinator = harness.build();
    coordinator.onInit();

    coordinator.updateProxyDraft(
      server: '127.0.0.1',
      port: '7890',
      username: '',
      password: '',
    );
    await coordinator.saveDraft();

    expect(harness.saveCalls, 1);
    expect(harness.restartCalls, 1);
  });
}

class _SettingsCoordinatorHarness {
  final _FakeSettingsRepository repository = _FakeSettingsRepository();
  final _FakeSessionGateway sessions = _FakeSessionGateway();

  int get saveCalls => repository.saveCalls;
  int get restartCalls => sessions.restartCalls;

  SettingsCoordinator build() {
    return SettingsCoordinator(repository, sessions, auth: sessions);
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings current = const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: null,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: false,
    batchSize: 5,
    throttleMs: 1200,
    proxy: ProxySettings.empty,
  );
  int saveCalls = 0;

  @override
  AppSettings load() => current;

  @override
  Future<void> save(AppSettings settings) async {
    saveCalls++;
    current = settings;
  }
}

class _FakeSessionGateway implements SessionQueryGateway, AuthGateway {
  int restartCalls = 0;

  @override
  Stream<TdAuthState> get authStates => const Stream<TdAuthState>.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

  @override
  Future<void> restart() async {
    restartCalls++;
  }

  @override
  Future<void> start() async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}
}
