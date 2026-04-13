import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/features/settings/application/settings_restart_policy.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/default_workbench.dart';
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
    'saveDraft lets coordinator evaluate restart policy after persistence',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..restartPolicy.shouldRestartResult = true;
      final coordinator = harness.build();
      coordinator.onInit();
      coordinator.updateProxyDraft(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
      );

      await coordinator.saveDraft();

      expect(harness.persistence.saveCalls, 1);
      expect(coordinator.isDirty.value, isFalse);
      expect(harness.restartPolicy.calls, 1);
      expect(harness.restartPolicy.previous?.proxy, ProxySettings.empty);
      expect(harness.restartPolicy.next?.proxy.server, '127.0.0.1');
      expect(harness.restartCalls, 1);
      await coordinator.saveDraft(restartOnProxyChange: false);

      expect(harness.persistence.saveCalls, 2);
      expect(harness.restartPolicy.calls, 2);
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

  test(
    'loadChats coalesces duplicate requests while a load is already running',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..chatLoader.loadCompleter = Completer<List<SelectableChat>>();
      final coordinator = harness.build();

      final firstLoad = coordinator.loadChats();
      final secondLoad = coordinator.loadChats();

      await Future<void>.delayed(Duration.zero);

      expect(harness.chatLoader.loadCalls, 1);

      harness.chatLoader.loadCompleter!.complete(const [
        SelectableChat(id: -1001, title: '频道一'),
      ]);
      await firstLoad;
      await secondLoad;

      expect(coordinator.chats.single.title, '频道一');
    },
  );

  test(
    'saveDraft does not commit or evaluate restart when persistence save fails',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..persistence.throwOnSave = true
        ..restartPolicy.shouldRestartResult = true;
      final coordinator = harness.build();
      coordinator.onInit();
      coordinator.updateProxyDraft(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
      );

      await expectLater(
        coordinator.saveDraft(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'save failed',
          ),
        ),
      );

      expect(harness.persistence.saveCalls, 1);
      expect(coordinator.isDirty.value, isTrue);
      expect(coordinator.savedSettings.value.proxy, ProxySettings.empty);
      expect(coordinator.draftSettings.value.proxy.server, '127.0.0.1');
      expect(harness.restartPolicy.calls, 0);
      expect(harness.restartCalls, 0);
    },
  );

  test('getCategory resolves from saved settings instead of draft edits', () {
    final harness = _SettingsCoordinatorHarness()
      ..persistence.loaded = const AppSettings(
        categories: <CategoryConfig>[
          CategoryConfig(
            key: 'news',
            targetChatId: 1001,
            targetChatTitle: '已保存目标',
          ),
        ],
        sourceChatId: null,
        fetchDirection: MessageFetchDirection.latestFirst,
        forwardAsCopy: false,
        batchSize: 5,
        throttleMs: 1200,
        proxy: ProxySettings.empty,
      );
    final coordinator = harness.build();
    coordinator.onInit();

    coordinator.updateCategoryDraft(
      key: 'news',
      chat: const SelectableChat(id: 2002, title: '草稿目标'),
    );

    expect(coordinator.getCategory('news').targetChatId, 1001);
  });

  test('updates tag source and default tags in draft only', () {
    final harness = _SettingsCoordinatorHarness();
    final coordinator = harness.build();
    coordinator.onInit();

    coordinator.updateTagSourceChatDraft(-1001);
    coordinator.addDefaultTagDraft('#摄影');

    expect(coordinator.isDirty.value, isTrue);
    expect(coordinator.savedSettings.value.tagSourceChatId, isNull);
    expect(coordinator.draftSettings.value.tagSourceChatId, -1001);
    expect(
      coordinator.draftSettings.value.tagGroups.single.tags.single.name,
      '摄影',
    );
  });

  test('updates theme mode in draft and discard restores saved value', () {
    final harness = _SettingsCoordinatorHarness()
      ..persistence.loaded = AppSettings.defaults().copyWith(
        themeMode: AppThemeMode.light,
      );
    final coordinator = harness.build();
    coordinator.onInit();

    coordinator.updateThemeModeDraft(AppThemeMode.dark);

    expect(coordinator.savedSettings.value.themeMode, AppThemeMode.light);
    expect(coordinator.draftSettings.value.themeMode, AppThemeMode.dark);

    coordinator.discardDraft();

    expect(coordinator.draftSettings.value.themeMode, AppThemeMode.light);
  });

  test(
    'updates default workbench in draft and discard restores saved value',
    () {
      final harness = _SettingsCoordinatorHarness()
        ..persistence.loaded = AppSettings.defaults().copyWith(
          defaultWorkbench: AppDefaultWorkbench.forwarding,
        );
      final coordinator = harness.build();
      coordinator.onInit();

      coordinator.updateDefaultWorkbenchDraft(AppDefaultWorkbench.tagging);

      expect(
        coordinator.savedSettings.value.defaultWorkbench,
        AppDefaultWorkbench.forwarding,
      );
      expect(
        coordinator.draftSettings.value.defaultWorkbench,
        AppDefaultWorkbench.tagging,
      );

      coordinator.discardDraft();

      expect(
        coordinator.draftSettings.value.defaultWorkbench,
        AppDefaultWorkbench.forwarding,
      );
    },
  );

  test(
    'saveDraft still commits saved settings when restart fails after persistence',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..restartPolicy.shouldRestartResult = true
        ..sessions.restartError = StateError('restart failed');
      final coordinator = harness.build();
      coordinator.onInit();
      coordinator.updateProxyDraft(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
      );

      await expectLater(coordinator.saveDraft(), completes);
      expect(coordinator.isDirty.value, isFalse);
      expect(coordinator.savedSettings.value.proxy.server, '127.0.0.1');
      expect(harness.restartCalls, 1);
    },
  );

  test(
    'saveDraft coalesces duplicate requests while a save is already running',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..restartPolicy.shouldRestartResult = true
        ..sessions.restartCompleter = Completer<void>();
      final coordinator = harness.build();
      coordinator.onInit();
      coordinator.updateProxyDraft(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
      );

      final firstSave = coordinator.saveDraft();
      final secondSave = coordinator.saveDraft();

      await Future<void>.delayed(Duration.zero);

      expect(harness.persistence.saveCalls, 1);
      expect(harness.restartCalls, 1);

      harness.sessions.restartCompleter!.complete();
      await firstSave;
      await secondSave;
    },
  );

  test(
    'savePageDraft bridges local page draft into persisted settings',
    () async {
      final harness = _SettingsCoordinatorHarness();
      final coordinator = harness.build();
      coordinator.onInit();

      final next = coordinator.savedSettings.value.updateFetchDirection(
        MessageFetchDirection.oldestFirst,
      );

      await coordinator.savePageDraft(next);

      expect(
        coordinator.savedSettings.value.fetchDirection,
        MessageFetchDirection.oldestFirst,
      );
      expect(
        coordinator.draftSettings.value.fetchDirection,
        MessageFetchDirection.oldestFirst,
      );
    },
  );

  test(
    'logout delegates to auth gateway when settings requests sign out',
    () async {
      final harness = _SettingsCoordinatorHarness();
      final coordinator = harness.build();

      await coordinator.logout();

      expect(harness.sessions.logoutCalls, 1);
    },
  );

  test(
    'savePageDraft ignores overlapping page saves until the in-flight save completes',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..persistence.saveCompleter = Completer<void>();
      final coordinator = harness.build();
      coordinator.onInit();

      final firstDraft = coordinator.savedSettings.value.updateFetchDirection(
        MessageFetchDirection.oldestFirst,
      );
      final secondDraft = coordinator.savedSettings.value.copyWith(
        themeMode: AppThemeMode.dark,
      );

      final firstSave = coordinator.savePageDraft(firstDraft);
      await Future<void>.delayed(Duration.zero);

      final secondSave = coordinator.savePageDraft(secondDraft);
      await Future<void>.delayed(Duration.zero);

      expect(harness.persistence.saveCalls, 1);
      expect(
        coordinator.draftSettings.value.fetchDirection,
        MessageFetchDirection.oldestFirst,
      );
      expect(
        coordinator.draftSettings.value.themeMode,
        isNot(AppThemeMode.dark),
      );

      harness.persistence.saveCompleter!.complete();
      await firstSave;
      await secondSave;

      expect(
        harness.persistence.lastSaved?.fetchDirection,
        MessageFetchDirection.oldestFirst,
      );
      expect(
        harness.persistence.lastSaved?.themeMode,
        isNot(AppThemeMode.dark),
      );
      expect(
        coordinator.savedSettings.value.fetchDirection,
        MessageFetchDirection.oldestFirst,
      );
      expect(
        coordinator.savedSettings.value.themeMode,
        isNot(AppThemeMode.dark),
      );
    },
  );
}

class _SettingsCoordinatorHarness {
  final _FakeSettingsRepository repository = _FakeSettingsRepository();
  final _FakeSessionGateway sessions = _FakeSessionGateway();
  final _FakeSettingsPersistenceService persistence =
      _FakeSettingsPersistenceService();
  final _FakeSettingsChatLoader chatLoader = _FakeSettingsChatLoader();
  final _FakeSettingsRestartPolicy restartPolicy = _FakeSettingsRestartPolicy();

  int get restartCalls => sessions.restartCalls;

  SettingsCoordinator build() {
    return SettingsCoordinator(
      repository,
      sessions,
      auth: sessions,
      draftCoordinator: SettingsDraftCoordinator(AppSettings.defaults()),
      persistence: persistence,
      restartPolicy: restartPolicy,
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
  int logoutCalls = 0;
  Object? restartError;
  Completer<void>? restartCompleter;

  @override
  Stream<TdAuthState> get authStates => const Stream<TdAuthState>.empty();

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

  @override
  Future<void> restart() async {
    restartCalls++;
    if (restartError != null) {
      throw restartError!;
    }
    final completer = restartCompleter;
    if (completer != null) {
      await completer.future;
    }
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
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
    proxy: ProxySettings.empty,
  );
  int loadCalls = 0;
  int saveCalls = 0;
  bool throwOnSave = false;
  AppSettings? lastSaved;
  Completer<void>? saveCompleter;

  @override
  AppSettings load() {
    loadCalls++;
    return loaded;
  }

  @override
  Future<void> save(AppSettings next) async {
    saveCalls++;
    if (throwOnSave) {
      throw StateError('save failed');
    }
    final completer = saveCompleter;
    if (completer != null) {
      await completer.future;
    }
    lastSaved = next;
  }
}

class _FakeSettingsRestartPolicy extends SettingsRestartPolicy {
  bool shouldRestartResult = false;
  int calls = 0;
  AppSettings? previous;
  AppSettings? next;

  @override
  bool shouldRestart(AppSettings previous, AppSettings next) {
    calls++;
    this.previous = previous;
    this.next = next;
    return shouldRestartResult;
  }
}

class _FakeSettingsChatLoader extends SettingsChatLoader {
  _FakeSettingsChatLoader() : super(sessionQueryGateway: _FakeSessionGateway());

  List<SelectableChat> chats = const [];
  int loadCalls = 0;
  Completer<List<SelectableChat>>? loadCompleter;

  @override
  Future<List<SelectableChat>> loadChats() async {
    loadCalls++;
    final completer = loadCompleter;
    if (completer != null) {
      return completer.future;
    }
    return chats;
  }
}
