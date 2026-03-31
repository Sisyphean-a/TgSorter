import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';
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

  final TelegramGateway _service;
  final stage = AuthStage.loading.obs;
  final loading = false.obs;
  final startupError = RxnString();

  StreamSubscription<AuthorizationState>? _authSub;

  @override
  void onInit() {
    super.onInit();
    _authSub = _service.authStates.listen(_onAuthState, onError: _onAuthError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
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
      startupError.value = null;
    } on TdlibRequestException catch (error) {
      _showTdlibError(error, '启动失败');
    } catch (error) {
      _showSafeError('启动失败', error.toString());
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

  void _showTdlibError(TdlibRequestException error, String title) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，请等待 $waitSeconds 秒';
      _showSafeError(title, '触发 FloodWait$suffix');
      return;
    }
    if (kind == TdErrorKind.network) {
      _showSafeError(title, '网络异常，请检查连接后重试');
      return;
    }
    if (kind == TdErrorKind.auth) {
      _showSafeError(title, '鉴权失败，请确认手机号/验证码/密码是否正确');
      return;
    }
    if (kind == TdErrorKind.permission) {
      _showSafeError(title, '权限受限，请检查 Telegram 账号状态');
      return;
    }
    _showSafeError(title, error.toString());
  }

  void _showSafeError(String title, String message) {
    startupError.value = '$title：$message';
    if (Get.context == null) {
      return;
    }
    Get.snackbar(title, message);
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    if (error is TdlibRequestException) {
      _showTdlibError(error, '授权初始化失败');
      return;
    }
    _showSafeError('授权初始化失败', error.toString());
  }
}
