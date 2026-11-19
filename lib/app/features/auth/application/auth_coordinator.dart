import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';

export 'package:tgsorter/app/features/auth/application/auth_lifecycle_coordinator.dart'
    show AuthStage;

class AuthCoordinator extends GetxController {
  AuthCoordinator(
    this._service,
    this._errors, {
    required AuthLifecycleCoordinator lifecycle,
  }) : _lifecycle = lifecycle;

  final AuthGateway _service;
  final AppErrorController _errors;
  final AuthLifecycleCoordinator _lifecycle;
  final stage = AuthStage.loading.obs;
  final loading = false.obs;

  RxnString get startupError => _errors.currentError;
  RxList<String> get errorHistory => _errors.errorHistory;
  AuthGateway get auth => _service;
  AppErrorController get errors => _errors;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lifecycle.initialize(
        onStageChanged: (nextStage) => stage.value = nextStage,
      );
    });
  }

  Future<void> submitPhone(String phone) async {
    await _runAction(
      action: () => _service.submitPhoneNumber(phone.trim()),
      errorTitle: '发送验证码失败',
    );
  }

  Future<void> submitCode(String code) async {
    await _runAction(
      action: () => _service.submitCode(code.trim()),
      errorTitle: '提交验证码失败',
    );
  }

  Future<void> submitPassword(String password) async {
    await _runAction(
      action: () => _service.submitPassword(password),
      errorTitle: '提交密码失败',
    );
  }

  Future<void> retryStartup() async {
    if (loading.value) return;
    final previousStage = stage.value;
    stage.value = AuthStage.loading;
    await _runAction(
      action: _service.restart,
      errorTitle: '启动失败',
      onError: () {
        if (stage.value == AuthStage.loading) {
          stage.value = previousStage;
        }
      },
    );
  }

  void clearErrorHistory() {
    _errors.clear();
  }

  Future<void> _runAction({
    required Future<void> Function() action,
    required String errorTitle,
    void Function()? onError,
  }) async {
    if (loading.value) {
      return;
    }
    loading.value = true;
    _errors.clearCurrent();
    try {
      await action();
    } catch (error) {
      onError?.call();
      _lifecycle.reportActionError(error, title: errorTitle);
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    _lifecycle.dispose();
    super.onClose();
  }
}
