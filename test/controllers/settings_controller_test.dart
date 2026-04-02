import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  group('SettingsController', () {
    test(
      'saveProxySettings persists values and restarts when requested',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final gateway = _SettingsFakeGateway();
        final controller = SettingsController(
          SettingsRepository(prefs),
          gateway,
        );
        controller.onInit();

        await controller.saveProxySettings(
          server: '127.0.0.1',
          port: '7897',
          username: 'user',
          password: 'pass',
          restart: true,
        );

        expect(controller.settings.value.proxy.server, '127.0.0.1');
        expect(controller.settings.value.proxy.port, 7897);
        expect(prefs.getString('tdlib_proxy_server'), '127.0.0.1');
        expect(prefs.getInt('tdlib_proxy_port'), 7897);
        expect(gateway.restartCount, 1);
      },
    );

    test('addCategory stores selected chat and blocks duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
      controller.onInit();

      await controller.addCategory(
        const SelectableChat(id: -1001, title: '频道一'),
      );

      expect(
        controller.settings.value.categories.single.targetChatTitle,
        '频道一',
      );

      expect(
        () => controller.addCategory(
          const SelectableChat(id: -1001, title: '频道一'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('saveForwardAsCopy persists switch value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
      controller.onInit();

      await controller.saveForwardAsCopy(true);

      expect(controller.settings.value.forwardAsCopy, isTrue);
      expect(prefs.getBool('forward_as_copy'), isTrue);
    });

    test('tracks draft changes and saves them in one pass', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
      controller.onInit();

      controller.updateSourceChatDraft(-10001);
      controller.updateFetchDirectionDraft(MessageFetchDirection.oldestFirst);
      controller.updateForwardAsCopyDraft(true);
      controller.updateBatchOptionsDraft(batchSize: 8, throttleMs: 1500);

      expect(controller.isDirty.value, isTrue);
      expect(controller.draftSettings.value.sourceChatId, -10001);
      expect(controller.savedSettings.value.sourceChatId, isNull);

      await controller.saveDraft();

      expect(controller.isDirty.value, isFalse);
      expect(controller.savedSettings.value.sourceChatId, -10001);
      expect(controller.savedSettings.value.fetchDirection, MessageFetchDirection.oldestFirst);
      expect(controller.savedSettings.value.forwardAsCopy, isTrue);
      expect(controller.savedSettings.value.batchSize, 8);
      expect(controller.savedSettings.value.throttleMs, 1500);
      expect(prefs.getString('source_chat_id'), '-10001');
      expect(prefs.getBool('forward_as_copy'), isTrue);
      expect(gateway.restartCount, 0);
    });

    test('discardDraft restores saved settings and drops category edits', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
      controller.onInit();
      await controller.saveDraft();

      controller.addCategoryDraft(
        const SelectableChat(id: -1001, title: '频道一'),
      );
      controller.updateProxyDraft(
        server: '127.0.0.1',
        port: '7897',
        username: '',
        password: '',
      );

      expect(controller.draftSettings.value.categories, hasLength(1));
      expect(controller.isDirty.value, isTrue);

      controller.discardDraft();

      expect(controller.isDirty.value, isFalse);
      expect(controller.draftSettings.value.categories, isEmpty);
      expect(controller.savedSettings.value.categories, isEmpty);
      expect(controller.draftSettings.value.proxy.server, isEmpty);
    });

    test('category draft changes persist only after saveDraft', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
      controller.onInit();

      controller.addCategoryDraft(
        const SelectableChat(id: -1001, title: '频道一'),
      );
      final category = controller.draftSettings.value.categories.single;
      controller.updateCategoryDraft(
        key: category.key,
        chat: const SelectableChat(id: -1002, title: '频道二'),
      );
      controller.removeCategoryDraft(category.key);
      controller.addCategoryDraft(
        const SelectableChat(id: -1003, title: '频道三'),
      );

      expect(controller.savedSettings.value.categories, isEmpty);
      expect(controller.draftSettings.value.categories.single.targetChatTitle, '频道三');

      await controller.saveDraft();

      expect(
        controller.savedSettings.value.categories,
        hasLength(1),
      );
      expect(
        controller.savedSettings.value.categories.single,
        isA<CategoryConfig>()
            .having((item) => item.targetChatId, 'targetChatId', -1003)
            .having((item) => item.targetChatTitle, 'targetChatTitle', '频道三'),
      );
      expect(prefs.getStringList('category_keys'), isNotEmpty);
    });
  });
}

class _SettingsFakeGateway implements TelegramGateway {
  int restartCount = 0;

  @override
  Stream<TdAuthState> get authStates => const Stream.empty();

  @override
  Stream<TdConnectionState> get connectionStates => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> restart() async {
    restartCount++;
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {}

  @override
  Future<void> submitCode(String code) async {}

  @override
  Future<void> submitPassword(String password) async {}

  @override
  Future<List<SelectableChat>> listSelectableChats() async => const [];

  @override
  Future<List<PipelineMessage>> fetchMessagePage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
    required int? fromMessageId,
    required int limit,
  }) async {
    return const [];
  }

  @override
  Future<PipelineMessage?> fetchNextMessage({
    required MessageFetchDirection direction,
    required int? sourceChatId,
  }) async {
    return null;
  }

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ClassifyReceipt> classifyMessage({
    required int? sourceChatId,
    required List<int> messageIds,
    required int targetChatId,
    required bool asCopy,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}
}
