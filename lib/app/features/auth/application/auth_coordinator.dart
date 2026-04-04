import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

export 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart'
    show AuthStage;

class AuthCoordinator extends GetxController {
  AuthCoordinator(
    this._service,
    this._errors,
    this._settings, {
    AuthErrorMapper errorMapper = const AuthErrorMapper(),
    required AuthLifecycleCoordinator lifecycle,
  }) : _errorMapper = errorMapper,
       _lifecycle = lifecycle;

  final AuthGateway _service;
  final AppErrorController _errors;
  final SettingsCoordinator _settings;
  final AuthErrorMapper _errorMapper;
  final AuthLifecycleCoordinator _lifecycle;
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
      _showSafeError('发送验证码失败', error);
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
      _showSafeError('提交验证码失败', error);
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
      _showSafeError('提交密码失败', error);
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
      _errors.clearCurrent();
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '启动失败');
    } catch (error) {
      _showSafeError('启动失败', error);
    } finally {
      loading.value = false;
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _service.start();
      _errors.clearCurrent();
    } on TdlibFailure catch (error) {
      _showTdlibError(error, '启动失败');
    } catch (error) {
      _showSafeError('启动失败', error);
    }
  }

  void _onAuthState(TdAuthState state) {
    stage.value = _lifecycle.handle(state);
  }

  void _showTdlibError(TdlibFailure error, String title) {
    _reportError(_errorMapper.mapTdlibFailure(error, title: title));
  }

  void _showSafeError(String title, Object error) {
    _reportError(_errorMapper.mapGeneralError(error, title: title));
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    if (error is TdlibFailure) {
      _showTdlibError(error, '授权初始化失败');
      return;
    }
    _showSafeError('授权初始化失败', error);
  }

  void clearErrorHistory() {
    _errors.clear();
  }

  void _reportError(AppErrorEvent event) {
    _errors.reportEvent(event);
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }
}
