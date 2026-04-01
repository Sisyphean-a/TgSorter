import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';

void main() {
  group('SettingsController', () {
    test('saveProxySettings persists values and restarts when requested', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
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
    });

    test('addCategory stores selected chat and blocks duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final gateway = _SettingsFakeGateway();
      final controller = SettingsController(SettingsRepository(prefs), gateway);
      controller.onInit();

      await controller.addCategory(const SelectableChat(id: -1001, title: '频道一'));

      expect(controller.settings.value.categories.single.targetChatTitle, '频道一');

      expect(
        () => controller.addCategory(const SelectableChat(id: -1001, title: '频道一')),
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
  Future<PipelineMessage> prepareVideoPlayback({
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
    required int messageId,
    required int targetChatId,
    required bool asCopy,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required int targetMessageId,
  }) async {}
}
