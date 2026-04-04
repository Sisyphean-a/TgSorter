import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';

void main() {
  test('onInit loads saved settings through persistence service', () {
    final harness = _SettingsCoordinatorHarness();
    final coordinator = harness.build();

    coordinator.onInit();

    expect(harness.persistence.loadCalls, 1);
    expect(
      coordinator.savedSettings.value.proxy.server,
      harness.persistence.loaded.proxy.server,
    );
  });

  test(
    'saveDraft delegates to persistence and restarts only when requested',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..persistence.shouldRestart = true;
      final coordinator = harness.build();
      coordinator.onInit();

      await coordinator.saveDraft();

      expect(harness.persistence.saveCalls, 1);
      expect(harness.restartCalls, 1);

      await coordinator.saveDraft(restartOnProxyChange: false);

      expect(harness.persistence.saveCalls, 2);
      expect(harness.restartCalls, 1);
    },
  );

  test('loadChats delegates to chat loader and exposes result', () async {
    final harness = _SettingsCoordinatorHarness()
      ..chatLoader.chats = const [SelectableChat(id: -1001, title: '频道一')];
    final coordinator = harness.build();

    await coordinator.loadChats();

    expect(harness.chatLoader.loadCalls, 1);
    expect(coordinator.chats.single.title, '频道一');
  });
}

class _SettingsCoordinatorHarness {
  final _FakeSettingsRepository repository = _FakeSettingsRepository();
  final _FakeSessionGateway sessions = _FakeSessionGateway();
  final _FakeSettingsPersistenceService persistence =
      _FakeSettingsPersistenceService();
  final _FakeSettingsChatLoader chatLoader = _FakeSettingsChatLoader();

  int get restartCalls => sessions.restartCalls;

  SettingsCoordinator build() {
    return SettingsCoordinator(
      repository,
      sessions,
      auth: sessions,
      draftCoordinator: SettingsDraftCoordinator(AppSettings.defaults()),
      persistence: persistence,
      chatLoader: chatLoader,
    );
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

class _FakeSettingsPersistenceService extends SettingsPersistenceService {
  _FakeSettingsPersistenceService() : super(_FakeSettingsRepository());

  AppSettings loaded = const AppSettings(
    categories: <CategoryConfig>[],
    sourceChatId: null,
    fetchDirection: MessageFetchDirection.latestFirst,
    forwardAsCopy: false,
    batchSize: 5,
    throttleMs: 1200,
    proxy: ProxySettings(
      server: '127.0.0.1',
      port: 7890,
      username: '',
      password: '',
    ),
  );
  bool shouldRestart = false;
  int loadCalls = 0;
  int saveCalls = 0;

  @override
  AppSettings load() {
    loadCalls++;
    return loaded;
  }

  @override
  Future<bool> saveDraft(SettingsDraftCoordinator draft) async {
    saveCalls++;
    draft.commit();
    return shouldRestart;
  }
}

class _FakeSettingsChatLoader extends SettingsChatLoader {
  _FakeSettingsChatLoader() : super(sessionQueryGateway: _FakeSessionGateway());

  List<SelectableChat> chats = const [];
  int loadCalls = 0;

  @override
  Future<List<SelectableChat>> loadChats() async {
    loadCalls++;
    return chats;
  }
}
