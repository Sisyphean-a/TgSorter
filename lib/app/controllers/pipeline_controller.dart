import 'dart:async';

import 'package:get/get.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

class PipelineController extends GetxController {
  PipelineController({
    required TelegramService service,
    required SettingsController settingsController,
  })  : _service = service,
        _settingsController = settingsController;

  final TelegramService _service;
  final SettingsController _settingsController;

  final currentMessage = Rxn<PipelineMessage>();
  final loading = false.obs;
  final processing = false.obs;
  final isOnline = false.obs;

  StreamSubscription<ConnectionState>? _connectionSub;

  @override
  void onInit() {
    super.onInit();
    _connectionSub = _service.connectionStates.listen((state) {
      isOnline.value = state is ConnectionStateReady;
    });
  }

  @override
  void onReady() {
    super.onReady();
    fetchNext();
  }

  Future<void> fetchNext() async {
    loading.value = true;
    try {
      currentMessage.value = await _service.fetchNextSavedMessage();
    } on TdlibRequestException catch (error) {
      _showTdlibError(error);
    } finally {
      loading.value = false;
    }
  }

  Future<void> classify(String key) async {
    if (processing.value || !isOnline.value) {
      return;
    }
    final message = currentMessage.value;
    if (message == null) {
      return;
    }

    final target = _settingsController.getCategory(key);
    if (target.targetChatId == null) {
      Get.snackbar('未配置目标会话', '请先在设置里填写 ${target.name} 的 Chat ID');
      return;
    }

    processing.value = true;
    try {
      await _service.classifyMessage(
        messageId: message.id,
        targetChatId: target.targetChatId!,
      );
      currentMessage.value = null;
      await fetchNext();
    } on TdlibRequestException catch (error) {
      _showTdlibError(error);
    } finally {
      processing.value = false;
    }
  }

  void _showTdlibError(TdlibRequestException error) {
    if (error.code == 420) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，需等待 $waitSeconds 秒';
      Get.snackbar('操作过快', '触发 FloodWait$suffix');
      return;
    }
    Get.snackbar('TDLib 错误', error.toString());
  }

  @override
  void onClose() {
    _connectionSub?.cancel();
    super.onClose();
  }
}
