import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/features/login_alerts/application/login_alert_workbench_controller.dart';
import 'package:tgsorter/app/services/login_alert_repository.dart';
import 'package:tgsorter/app/services/telegram_login_alert.dart';

void main() {
  test(
    'deduplicates updateNewMessage and updateChatLastMessage by message id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final updates = StreamController<Map<String, dynamic>>.broadcast();
      late LoginAlertWorkbenchController controller;
      addTearDown(() async {
        controller.onClose();
        await updates.close();
      });
      controller = LoginAlertWorkbenchController(
        updates: updates.stream,
        repository: LoginAlertRepository(prefs),
        nowMs: () => 1700000000000,
      );

      controller.onInit();
      updates.add(_codeUpdate(type: 'updateNewMessage'));
      updates.add(_codeUpdate(type: 'updateChatLastMessage'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.code, '404237');
    },
  );

  test('marks latest active code as used when new login alert arrives', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final updates = StreamController<Map<String, dynamic>>.broadcast();
    late LoginAlertWorkbenchController controller;
    addTearDown(() async {
      controller.onClose();
      await updates.close();
    });
    controller = LoginAlertWorkbenchController(
      updates: updates.stream,
      repository: LoginAlertRepository(prefs),
      nowMs: () => 1700000000000,
    );

    controller.onInit();
    updates.add(_codeUpdate(type: 'updateNewMessage'));
    await Future<void>.delayed(Duration.zero);
    updates.add(<String, dynamic>{
      '@type': 'updateNewMessage',
      'message': <String, dynamic>{
        '@type': 'message',
        'id': 19,
        'chat_id': 777000,
        'date': 1700000005,
        'sender_id': <String, dynamic>{
          '@type': 'messageSenderUser',
          'user_id': 777000,
        },
        'content': <String, dynamic>{
          '@type': 'messageText',
          'text': <String, dynamic>{
            'text':
                'New login.\nDevice: Telegram Desktop\nLocation: Hangzhou, China',
            'entities': <Object>[],
          },
        },
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.entries, hasLength(2));
    expect(controller.entries.first.kind, TelegramLoginAlertKind.newLogin);
    final codeEntry = controller.entries.last;
    expect(codeEntry.kind, TelegramLoginAlertKind.code);
    expect(codeEntry.status, TelegramLoginAlertStatus.used);
  });

  test(
    'marks code as used when new login arrives before code update',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final updates = StreamController<Map<String, dynamic>>.broadcast();
      late LoginAlertWorkbenchController controller;
      addTearDown(() async {
        controller.onClose();
        await updates.close();
      });
      controller = LoginAlertWorkbenchController(
        updates: updates.stream,
        repository: LoginAlertRepository(prefs),
        nowMs: () => 1700000000000,
      );

      controller.onInit();
      updates.add(_newLoginUpdate());
      await Future<void>.delayed(Duration.zero);
      updates.add(_codeUpdate(type: 'updateNewMessage'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, hasLength(2));
      final codeEntry = controller.entries.firstWhere(
        (item) => item.kind == TelegramLoginAlertKind.code,
      );
      expect(codeEntry.status, TelegramLoginAlertStatus.used);
      expect(codeEntry.consumedAtMs, 1700000005000);
    },
  );

  test('recomputes used status from restored code and login history', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = LoginAlertRepository(prefs);
    await repository.save(const <TelegramLoginAlert>[
      TelegramLoginAlert(
        kind: TelegramLoginAlertKind.code,
        status: TelegramLoginAlertStatus.active,
        messageId: 18,
        chatId: 777000,
        receivedAtMs: 1700000000000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'Login code: 404237',
        code: '404237',
      ),
      TelegramLoginAlert(
        kind: TelegramLoginAlertKind.newLogin,
        status: TelegramLoginAlertStatus.info,
        messageId: 19,
        chatId: 777000,
        receivedAtMs: 1700000005000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'New login.\nDevice: Telegram Desktop\nLocation: Hangzhou, China',
        deviceSummary: 'Telegram Desktop',
        location: 'Hangzhou, China',
      ),
    ]);
    final controller = LoginAlertWorkbenchController(
      updates: const Stream<Map<String, dynamic>>.empty(),
      repository: repository,
      nowMs: () => 1700000000000,
    );
    addTearDown(controller.onClose);

    controller.onInit();
    await Future<void>.delayed(Duration.zero);

    final codeEntry = controller.entries.firstWhere(
      (item) => item.kind == TelegramLoginAlertKind.code,
    );
    expect(codeEntry.status, TelegramLoginAlertStatus.used);
    expect(codeEntry.consumedAtMs, 1700000005000);
  });

  test(
    'restored empty state does not overwrite alert captured during bootstrap',
    () async {
      final updates = StreamController<Map<String, dynamic>>.broadcast();
      final repository = _DelayedLoginAlertRepository();
      late LoginAlertWorkbenchController controller;
      addTearDown(() async {
        controller.onClose();
        await updates.close();
      });
      controller = LoginAlertWorkbenchController(
        updates: updates.stream,
        repository: repository,
        nowMs: () => 1700000000000,
      );

      controller.onInit();
      updates.add(_codeUpdate(type: 'updateNewMessage'));
      await Future<void>.delayed(Duration.zero);
      repository.completeLoad(const <TelegramLoginAlert>[]);
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.code, '404237');
    },
  );

  test(
    'clearSessionStateForLogout clears entries and persisted inbox',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repository = LoginAlertRepository(prefs);
      await repository.save(const <TelegramLoginAlert>[
        TelegramLoginAlert(
          kind: TelegramLoginAlertKind.code,
          status: TelegramLoginAlertStatus.active,
          messageId: 18,
          chatId: 777000,
          receivedAtMs: 1700000000000,
          sourceLabel: 'Telegram 官方账号 777000',
          text: 'Login code: 404237',
          code: '404237',
        ),
      ]);
      late LoginAlertWorkbenchController controller;
      controller = LoginAlertWorkbenchController(
        updates: const Stream<Map<String, dynamic>>.empty(),
        repository: repository,
        nowMs: () => 1700000000000,
      );
      addTearDown(controller.onClose);

      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(controller.entries, hasLength(1));

      await controller.clearSessionStateForLogout();

      expect(controller.entries, isEmpty);
      expect(await repository.load(), isEmpty);
    },
  );

  test('clearSessionStateForLogout ignores stale restore result', () async {
    final updates = StreamController<Map<String, dynamic>>.broadcast();
    final repository = _DelayedLoginAlertRepository();
    late LoginAlertWorkbenchController controller;
    addTearDown(() async {
      controller.onClose();
      await updates.close();
    });
    controller = LoginAlertWorkbenchController(
      updates: updates.stream,
      repository: repository,
      nowMs: () => 1700000000000,
    );

    controller.onInit();
    await controller.clearSessionStateForLogout();
    repository.completeLoad(const <TelegramLoginAlert>[
      TelegramLoginAlert(
        kind: TelegramLoginAlertKind.code,
        status: TelegramLoginAlertStatus.active,
        messageId: 18,
        chatId: 777000,
        receivedAtMs: 1700000000000,
        sourceLabel: 'Telegram 官方账号 777000',
        text: 'Login code: 404237',
        code: '404237',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.entries, isEmpty);
  });

  test(
    'clearSessionStateForLogout ignores stale realtime updates until auth is ready again',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final updates = StreamController<Map<String, dynamic>>.broadcast();
      late LoginAlertWorkbenchController controller;
      addTearDown(() async {
        controller.onClose();
        await updates.close();
      });
      controller = LoginAlertWorkbenchController(
        updates: updates.stream,
        repository: LoginAlertRepository(prefs),
        nowMs: () => 1700000000000,
      );

      controller.onInit();
      await controller.clearSessionStateForLogout();

      updates.add(_codeUpdate(type: 'updateNewMessage'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.entries, isEmpty);

      updates.add(_authUpdate('authorizationStateReady'));
      updates.add(_codeUpdate(type: 'updateNewMessage'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, hasLength(1));
      expect(controller.entries.single.code, '404237');
    },
  );
}

Map<String, dynamic> _codeUpdate({required String type}) {
  final message = <String, dynamic>{
    '@type': 'message',
    'id': 18,
    'chat_id': 777000,
    'date': 1700000000,
    'sender_id': <String, dynamic>{
      '@type': 'messageSenderUser',
      'user_id': 777000,
    },
    'content': <String, dynamic>{
      '@type': 'messageText',
      'text': <String, dynamic>{
        'text': 'Login code: 404237',
        'entities': <Object>[],
      },
    },
  };
  if (type == 'updateChatLastMessage') {
    return <String, dynamic>{
      '@type': type,
      'chat_id': 777000,
      'last_message': message,
    };
  }
  return <String, dynamic>{'@type': type, 'message': message};
}

Map<String, dynamic> _authUpdate(String stateType) {
  return <String, dynamic>{
    '@type': 'updateAuthorizationState',
    'authorization_state': <String, dynamic>{'@type': stateType},
  };
}

Map<String, dynamic> _newLoginUpdate() {
  return <String, dynamic>{
    '@type': 'updateNewMessage',
    'message': <String, dynamic>{
      '@type': 'message',
      'id': 19,
      'chat_id': 777000,
      'date': 1700000005,
      'sender_id': <String, dynamic>{
        '@type': 'messageSenderUser',
        'user_id': 777000,
      },
      'content': <String, dynamic>{
        '@type': 'messageText',
        'text': <String, dynamic>{
          'text':
              'New login.\nDevice: Telegram Desktop\nLocation: Hangzhou, China',
          'entities': <Object>[],
        },
      },
    },
  };
}

class _DelayedLoginAlertRepository implements LoginAlertRepositoryPort {
  final Completer<List<TelegramLoginAlert>> _loadCompleter =
      Completer<List<TelegramLoginAlert>>();

  @override
  Future<List<TelegramLoginAlert>> load() => _loadCompleter.future;

  @override
  Future<void> save(List<TelegramLoginAlert> entries) async {}

  @override
  Future<void> clear() async {}

  void completeLoad(List<TelegramLoginAlert> entries) {
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete(entries);
    }
  }
}
