import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/controllers/pipeline_controller.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/classify_operation_log.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/models/proxy_settings.dart';
import 'package:tgsorter/app/pages/pipeline_mobile_view.dart';
import 'package:tgsorter/app/services/operation_journal_repository.dart';
import 'package:tgsorter/app/services/settings_repository.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
import 'package:tgsorter/app/widgets/mobile_action_tray.dart';

void main() {
  testWidgets('mobile skip button avoids 跳过 wording', (tester) async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _FakeTelegramService();
    final settingsController = SettingsController(
      SettingsRepository(prefs),
      service,
    );
    settingsController.onInit();
    settingsController.settings.value = const AppSettings(
      categories: [
        CategoryConfig(key: 'a', targetChatId: 10001, targetChatTitle: '分类一'),
      ],
      sourceChatId: 8888,
      fetchDirection: MessageFetchDirection.latestFirst,
      forwardAsCopy: false,
      batchSize: 2,
      throttleMs: 0,
      proxy: ProxySettings.empty,
    );
    final controller = PipelineController(
      service: service,
      settingsController: settingsController,
      journalRepository: OperationJournalRepository(prefs),
      errorController: AppErrorController(),
    );
    controller.onInit();
    controller.logs.assignAll(const [
      ClassifyOperationLog(
        id: 'log-1',
        categoryKey: 'a',
        messageId: 1,
        targetChatId: 10001,
        createdAtMs: 0,
        status: ClassifyOperationStatus.success,
      ),
    ]);
    controller.currentMessage.value = PipelineMessage(
      id: 1,
      messageIds: const [1],
      sourceChatId: 8888,
      preview: const MessagePreview(kind: MessagePreviewKind.text, title: 'hi'),
    );
    controller.isOnline.value = true;
    controller.remainingCount.value = 12;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PipelineMobileView(
            pipeline: controller,
            settings: settingsController,
          ),
        ),
      ),
    );

    expect(find.text('跳过当前'), findsNothing);
    expect(find.text('略过此条'), findsOneWidget);
    expect(find.text('失败重试队列：0'), findsNothing);
    expect(find.text('重试下一条'), findsNothing);
    expect(find.text('剩余：12'), findsNothing);
    expect(find.textContaining('成功 m:1'), findsNothing);
    expect(find.byKey(const Key('mobile-message-pane')), findsOneWidget);
    expect(find.byType(MobileActionTray), findsOneWidget);
    expect(find.byKey(const Key('mobile-secondary-actions')), findsOneWidget);
  });
}

class _FakeTelegramService implements TelegramGateway {
  final _authController = StreamController<TdAuthState>.broadcast();
  final _connectionController = StreamController<TdConnectionState>.broadcast();

  @override
  Stream<TdAuthState> get authStates => _authController.stream;

  @override
  Stream<TdConnectionState> get connectionStates =>
      _connectionController.stream;

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
  Future<List<SelectableChat>> listSelectableChats() async => const [];

  @override
  Future<int> countRemainingMessages({required int? sourceChatId}) async => 0;

  @override
  Future<PipelineMessage> prepareMediaPlayback({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> prepareMediaPreview({
    required int sourceChatId,
    required int messageId,
  }) async {}

  @override
  Future<PipelineMessage> refreshMessage({
    required int sourceChatId,
    required int messageId,
  }) async {
    throw UnimplementedError();
  }

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

  @override
  Future<void> undoClassify({
    required int sourceChatId,
    required int targetChatId,
    required List<int> targetMessageIds,
  }) async {}
}
