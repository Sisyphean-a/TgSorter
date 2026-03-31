import 'dart:async';

import 'package:get/get.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/telegram_service.dart';

enum AuthStage {
  loading,
  waitPhone,
  waitCode,
  waitPassword,
  ready,
  unsupported,
}

class AuthController extends GetxController {
  AuthController(this._service);

  final TelegramService _service;
  final stage = AuthStage.loading.obs;
  final loading = false.obs;

  StreamSubscription<AuthorizationState>? _authSub;

  @override
  void onInit() {
    super.onInit();
    _authSub = _service.authStates.listen(_onAuthState);
    _bootstrap();
  }

  Future<void> submitPhone(String phone) async {
    loading.value = true;
    try {
      await _service.submitPhoneNumber(phone.trim());
    } finally {
      loading.value = false;
    }
  }

  Future<void> submitCode(String code) async {
    loading.value = true;
    try {
      await _service.submitCode(code.trim());
    } finally {
      loading.value = false;
    }
  }

  Future<void> submitPassword(String password) async {
    loading.value = true;
    try {
      await _service.submitPassword(password.trim());
    } finally {
      loading.value = false;
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _service.start();
    } catch (error) {
      Get.snackbar('启动失败', error.toString());
    }
  }

  void _onAuthState(AuthorizationState state) {
    if (state is AuthorizationStateWaitPhoneNumber) {
      stage.value = AuthStage.waitPhone;
      return;
    }
    if (state is AuthorizationStateWaitCode) {
      stage.value = AuthStage.waitCode;
      return;
    }
    if (state is AuthorizationStateWaitPassword) {
      stage.value = AuthStage.waitPassword;
      return;
    }
    if (state is AuthorizationStateReady) {
      stage.value = AuthStage.ready;
      Get.offNamed('/pipeline');
      return;
    }
    stage.value = AuthStage.loading;
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }
}
