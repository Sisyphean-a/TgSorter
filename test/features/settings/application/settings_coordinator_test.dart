import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/settings/application/settings_chat_loader.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_draft_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_persistence_service.dart';
import 'package:tgsorter/app/features/settings/application/settings_restart_policy.dart';
import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_port.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/skipped_message_repository.dart';
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
    'saveProxySettings lets coordinator evaluate restart policy after persistence',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..restartPolicy.shouldRestartResult = true;
      final coordinator = harness.build();
      coordinator.onInit();
      await coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
        restart: true,
      );

      expect(harness.persistence.saveCalls, 1);
      expect(harness.draftCoordinator.isDirty.value, isFalse);
      expect(harness.restartPolicy.calls, 1);
      expect(harness.restartPolicy.previous?.proxy, ProxySettings.empty);
      expect(harness.restartPolicy.next?.proxy.server, '127.0.0.1');
      expect(harness.restartCalls, 1);
      await coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7891',
        username: '',
        password: '',
        restart: false,
      );

      expect(harness.persistence.saveCalls, 2);
      expect(harness.restartPolicy.calls, 2);
      expect(harness.restartCalls, 1);
    },
  );

  test(
    'saveProxySettings persists proxy only and does not leak unrelated draft edits',
    () async {
      final harness = _SettingsCoordinatorHarness();
      final coordinator = harness.build();
      coordinator.onInit();
      harness.draftCoordinator.update(
        coordinator.savedSettings.value.copyWith(
          defaultWorkbench: AppDefaultWorkbench.tagging,
        ),
      );

      await coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
        restart: false,
      );

      expect(
        coordinator.savedSettings.value.defaultWorkbench,
        AppDefaultWorkbench.forwarding,
      );
      expect(coordinator.savedSettings.value.proxy.server, '127.0.0.1');
      expect(coordinator.savedSettings.value.proxy.port, 7890);
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
    'saveProxySettings does not commit or evaluate restart when persistence save fails',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..persistence.throwOnSave = true
        ..restartPolicy.shouldRestartResult = true;
      final coordinator = harness.build();
      coordinator.onInit();

      await expectLater(
        coordinator.saveProxySettings(
          server: '127.0.0.1',
          port: '7890',
          username: '',
          password: '',
          restart: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'save failed',
          ),
        ),
      );

      expect(harness.persistence.saveCalls, 1);
      expect(coordinator.savedSettings.value.proxy, ProxySettings.empty);
      expect(harness.draftCoordinator.draft.value.proxy.server, '127.0.0.1');
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

    harness.draftCoordinator.update(
      coordinator.savedSettings.value.updateCategory(
        const CategoryConfig(
          key: 'news',
          targetChatId: 2002,
          targetChatTitle: '草稿目标',
        ),
      ),
    );

    expect(coordinator.getCategory('news').targetChatId, 1001);
  });

  test(
    'saveProxySettings still commits saved settings when restart fails after persistence',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..restartPolicy.shouldRestartResult = true
        ..sessions.restartError = StateError('restart failed');
      final coordinator = harness.build();
      coordinator.onInit();
      await coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
        restart: true,
      );
      expect(coordinator.savedSettings.value.proxy.server, '127.0.0.1');
      expect(harness.restartCalls, 1);
    },
  );

  test(
    'saveProxySettings coalesces duplicate requests while a save is already running',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..restartPolicy.shouldRestartResult = true
        ..sessions.restartCompleter = Completer<void>();
      final coordinator = harness.build();
      coordinator.onInit();
      final firstSave = coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
        restart: true,
      );
      final secondSave = coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7891',
        username: '',
        password: '',
        restart: true,
      );

      await Future<void>.delayed(Duration.zero);

      expect(harness.persistence.saveCalls, 1);
      expect(harness.restartCalls, 1);

      harness.sessions.restartCompleter!.complete();
      await firstSave;
      await secondSave;
    },
  );

  test(
    'saveProxySettings ignores overlapping updates while persistence is still in flight',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..persistence.saveCompleter = Completer<void>();
      final coordinator = harness.build();
      coordinator.onInit();

      final firstSave = coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7890',
        username: '',
        password: '',
        restart: false,
      );
      await Future<void>.delayed(Duration.zero);

      final secondSave = coordinator.saveProxySettings(
        server: '127.0.0.1',
        port: '7891',
        username: '',
        password: '',
        restart: false,
      );
      await Future<void>.delayed(Duration.zero);

      expect(harness.persistence.saveCalls, 1);
      expect(harness.persistence.lastSaved, isNull);

      harness.persistence.saveCompleter!.complete();
      await firstSave;
      await secondSave;

      expect(harness.persistence.lastSaved?.proxy.port, 7890);
      expect(coordinator.savedSettings.value.proxy.port, 7890);
      expect(harness.draftCoordinator.draft.value.proxy.port, 7890);
      expect(harness.draftCoordinator.isDirty.value, isFalse);
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
    'clearSessionStateForLogout drops skipped records and refreshes summary',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..skippedRepository.records = <SkippedMessageRecord>[
          SkippedMessageRecord(
            id: 'forwarding:8888:1',
            workflow: SkippedMessageWorkflow.forwarding,
            sourceChatId: 8888,
            primaryMessageId: 1,
            messageIds: const <int>[1],
            createdAtMs: 1,
          ),
        ];
      final coordinator = harness.build();

      coordinator.refreshSkippedMessageSummary();
      expect(coordinator.skippedMessageSummary.value.totalCount, 1);

      await coordinator.clearSessionStateForLogout();

      expect(harness.skippedRepository.records, isEmpty);
      expect(coordinator.skippedMessageSummary.value.totalCount, 0);
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
        harness.draftCoordinator.draft.value.fetchDirection,
        MessageFetchDirection.oldestFirst,
      );
      expect(
        harness.draftCoordinator.draft.value.themeMode,
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

  test(
    'refreshSkippedSummary groups skipped records by workflow and source',
    () {
      final harness = _SettingsCoordinatorHarness()
        ..skippedRepository.records = <SkippedMessageRecord>[
          SkippedMessageRecord(
            id: 'forwarding:8888:1',
            workflow: SkippedMessageWorkflow.forwarding,
            sourceChatId: 8888,
            primaryMessageId: 1,
            messageIds: const <int>[1],
            createdAtMs: 1,
          ),
          SkippedMessageRecord(
            id: 'forwarding:8888:2',
            workflow: SkippedMessageWorkflow.forwarding,
            sourceChatId: 8888,
            primaryMessageId: 2,
            messageIds: const <int>[2],
            createdAtMs: 2,
          ),
          SkippedMessageRecord(
            id: 'tagging:9999:3',
            workflow: SkippedMessageWorkflow.tagging,
            sourceChatId: 9999,
            primaryMessageId: 3,
            messageIds: const <int>[3],
            createdAtMs: 3,
          ),
        ];
      final coordinator = harness.build();

      coordinator.refreshSkippedMessageSummary();

      expect(coordinator.skippedMessageSummary.value.totalCount, 3);
      expect(coordinator.skippedMessageSummary.value.forwardingCount, 2);
      expect(coordinator.skippedMessageSummary.value.taggingCount, 1);
      expect(
        coordinator.skippedMessageSummary.value.sources.map(
          (item) => item.count,
        ),
        [2, 1],
      );
    },
  );

  test(
    'restoreSkippedMessages notifies matching workflow targets only',
    () async {
      final harness = _SettingsCoordinatorHarness()
        ..skippedRepository.records = <SkippedMessageRecord>[
          SkippedMessageRecord(
            id: 'forwarding:8888:1',
            workflow: SkippedMessageWorkflow.forwarding,
            sourceChatId: 8888,
            primaryMessageId: 1,
            messageIds: const <int>[1],
            createdAtMs: 1,
          ),
          SkippedMessageRecord(
            id: 'tagging:9999:3',
            workflow: SkippedMessageWorkflow.tagging,
            sourceChatId: 9999,
            primaryMessageId: 3,
            messageIds: const <int>[3],
            createdAtMs: 3,
          ),
        ];
      final forwardingTarget = _FakeSkippedMessageRestorePort(
        SkippedMessageWorkflow.forwarding,
      );
      final taggingTarget = _FakeSkippedMessageRestorePort(
        SkippedMessageWorkflow.tagging,
      );
      harness.restoreTargets = <SkippedMessageRestorePort>[
        forwardingTarget,
        taggingTarget,
      ];
      final coordinator = harness.build();

      final restored = await coordinator.restoreSkippedMessages(
        workflow: SkippedMessageWorkflow.forwarding,
        sourceChatId: 8888,
      );

      expect(restored, 1);
      expect(forwardingTarget.restoreCalls, 1);
      expect(forwardingTarget.lastSourceChatId, 8888);
      expect(taggingTarget.restoreCalls, 0);
      expect(coordinator.skippedMessageSummary.value.totalCount, 1);
    },
  );
}

class _SettingsCoordinatorHarness {
  final _FakeSettingsRepository repository = _FakeSettingsRepository();
  final _FakeSessionGateway sessions = _FakeSessionGateway();
  final SettingsDraftCoordinator draftCoordinator = SettingsDraftCoordinator(
    AppSettings.defaults(),
  );
  final _FakeSettingsPersistenceService persistence =
      _FakeSettingsPersistenceService();
  final _FakeSettingsChatLoader chatLoader = _FakeSettingsChatLoader();
  final _FakeSettingsRestartPolicy restartPolicy = _FakeSettingsRestartPolicy();
  final _FakeSkippedMessageRepository skippedRepository =
      _FakeSkippedMessageRepository();
  List<SkippedMessageRestorePort> restoreTargets =
      <SkippedMessageRestorePort>[];

  int get restartCalls => sessions.restartCalls;

  SettingsCoordinator build() {
    return SettingsCoordinator(
      repository,
      sessions,
      auth: sessions,
      draftCoordinator: draftCoordinator,
      persistence: persistence,
      restartPolicy: restartPolicy,
      chatLoader: chatLoader,
      skippedMessageRepository: skippedRepository,
      skippedRestoreTargets: restoreTargets,
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

class _FakeSkippedMessageRepository implements SkippedMessageRepository {
  List<SkippedMessageRecord> records = <SkippedMessageRecord>[];

  @override
  bool containsMessage({
    required SkippedMessageWorkflow workflow,
    required int sourceChatId,
    required Iterable<int> messageIds,
  }) {
    final ids = messageIds.toSet();
    return records.any(
      (item) =>
          item.workflow == workflow &&
          item.sourceChatId == sourceChatId &&
          item.messageIds.any(ids.contains),
    );
  }

  @override
  int countSkippedMessages({
    required SkippedMessageWorkflow workflow,
    int? sourceChatId,
  }) {
    return records.where((item) {
      return item.workflow == workflow &&
          (sourceChatId == null || item.sourceChatId == sourceChatId);
    }).length;
  }

  @override
  List<SkippedMessageRecord> loadSkippedMessages() =>
      List<SkippedMessageRecord>.from(records);

  @override
  Future<int> restoreSkippedMessages({
    SkippedMessageWorkflow? workflow,
    int? sourceChatId,
  }) async {
    final current = List<SkippedMessageRecord>.from(records);
    records = current
        .where((item) {
          if (workflow != null && item.workflow != workflow) {
            return true;
          }
          if (sourceChatId != null && item.sourceChatId != sourceChatId) {
            return true;
          }
          return false;
        })
        .toList(growable: false);
    return current.length - records.length;
  }

  @override
  Future<void> clearAll() async {
    records = <SkippedMessageRecord>[];
  }

  @override
  Future<void> saveSkippedMessages(List<SkippedMessageRecord> records) async {
    this.records = List<SkippedMessageRecord>.from(records);
  }

  @override
  Future<void> upsertSkippedMessage(SkippedMessageRecord record) async {
    records = List<SkippedMessageRecord>.from(records)..add(record);
  }
}

class _FakeSkippedMessageRestorePort implements SkippedMessageRestorePort {
  _FakeSkippedMessageRestorePort(this.workflow);

  @override
  final SkippedMessageWorkflow workflow;

  int restoreCalls = 0;
  int? lastSourceChatId;

  @override
  Future<void> reloadAfterSkippedRestore({int? sourceChatId}) async {
    restoreCalls++;
    lastSourceChatId = sourceChatId;
  }
}
