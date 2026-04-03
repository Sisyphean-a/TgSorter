import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

import 'auth_gateway.dart';

enum AuthStage {
  loading,
  waitPhone,
  waitCode,
  waitPassword,
  ready,
  unsupported,
}

class AuthCoordinator extends GetxController {
  AuthCoordinator(this._service, this._errors, this._settings);

  final AuthGateway _service;
  final AppErrorController _errors;
  final SettingsCoordinator _settings;
  final stage = AuthStage.loading.obs;
  final loading = false.obs;

  StreamSubscription<TdAuthState>? _authSub;

  RxnString get startupError => _errors.currentError;
  RxList<String> get errorHistory => _errors.errorHistory;
  SettingsCoordinator get settings => _settings;
  AuthGateway get auth => _service;
  AppErrorController get errors => _errors;

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
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '发送验证码失败');
    } catch (error) {
      _showSafeError('发送验证码失败', error.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> submitCode(String code) async {
    loading.value = true;
    try {
      await _service.submitCode(code.trim());
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '提交验证码失败');
    } catch (error) {
      _showSafeError('提交验证码失败', error.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> submitPassword(String password) async {
    loading.value = true;
    try {
      await _service.submitPassword(password.trim());
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '提交密码失败');
    } catch (error) {
      _showSafeError('提交密码失败', error.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> saveProxyAndRetry({
    required String server,
    required String port,
    required String username,
    required String password,
  }) async {
    loading.value = true;
    try {
      await _settings.saveProxySettings(
        server: server,
        port: port,
        username: username,
        password: password,
      );
      _errors.clear();
      stage.value = AuthStage.loading;
      await _service.restart();
      startupError.value = null;
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '启动失败');
    } catch (error) {
      _showSafeError('启动失败', error.toString());
    } finally {
      loading.value = false;
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _service.start();
      startupError.value = null;
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '启动失败');
    } catch (error) {
      _showSafeError('启动失败', error.toString());
    }
  }

  void _onAuthState(TdAuthState state) {
    if (state.kind == TdAuthStateKind.waitPhoneNumber) {
      stage.value = AuthStage.waitPhone;
      return;
    }
    if (state.kind == TdAuthStateKind.waitCode) {
      stage.value = AuthStage.waitCode;
      return;
    }
    if (state.kind == TdAuthStateKind.waitPassword) {
      stage.value = AuthStage.waitPassword;
      return;
    }
    if (state.kind == TdAuthStateKind.ready) {
      stage.value = AuthStage.ready;
      Get.offNamed(AppRoutes.pipeline);
      return;
    }
    stage.value = AuthStage.loading;
  }

  void _showTdlibError(TdlibFailure error, String title) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，请等待 $waitSeconds 秒';
      _showSafeError(title, '触发 FloodWait$suffix');
      return;
    }
    if (kind == TdErrorKind.network) {
      _showSafeError(title, '网络异常：${error.message}');
      return;
    }
    if (kind == TdErrorKind.auth) {
      _showSafeError(title, '鉴权失败：${error.message}');
      return;
    }
    if (kind == TdErrorKind.permission) {
      _showSafeError(title, '权限受限，请检查 Telegram 账号状态');
      return;
    }
    _showSafeError(title, error.toString());
  }

  void _showSafeError(String title, String message) {
    _errors.report(title: title, message: message);
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    if (error is TdlibFailure) {
      _showTdlibError(error, '授权初始化失败');
      return;
    }
    _showSafeError('授权初始化失败', error.toString());
  }

  void clearErrorHistory() {
    _errors.clear();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }
}
