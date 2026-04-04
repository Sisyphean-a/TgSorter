import 'dart:async';

import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

enum AuthStage {
  loading,
  waitPhone,
  waitCode,
  waitPassword,
  ready,
  unsupported,
}

class AuthLifecycleCoordinator {
  AuthLifecycleCoordinator({
    required AuthGateway auth,
    required AppErrorController errors,
    required AuthErrorMapper errorMapper,
    required AuthNavigationPort navigation,
  }) : _auth = auth,
       _errors = errors,
       _errorMapper = errorMapper,
       _navigation = navigation;

  final AuthGateway _auth;
  final AppErrorController _errors;
  final AuthErrorMapper _errorMapper;
  final AuthNavigationPort _navigation;
  StreamSubscription<TdAuthState>? _authSub;

  void initialize({required void Function(AuthStage stage) onStageChanged}) {
    final previousSub = _authSub;
    if (previousSub != null) {
      unawaited(previousSub.cancel());
    }
    _authSub = _auth.authStates.listen(
      (state) => onStageChanged(_handle(state)),
      onError: _onAuthError,
    );
    unawaited(bootstrap());
  }

  Future<void> bootstrap() async {
    try {
      await _auth.start();
      _errors.clearCurrent();
    } on TdlibFailure catch (error) {
      _reportTdlibError(error, title: '启动失败');
    } catch (error) {
      _reportGeneralError(error, title: '启动失败');
    }
  }

  void reportActionError(Object error, {required String title}) {
    if (error is TdlibFailure) {
      _reportTdlibError(error, title: title);
      return;
    }
    _reportGeneralError(error, title: title);
  }

  void dispose() {
    _authSub?.cancel();
    _authSub = null;
  }

  AuthStage _handle(TdAuthState state) {
    if (state.kind == TdAuthStateKind.waitPhoneNumber) {
      return AuthStage.waitPhone;
    }
    if (state.kind == TdAuthStateKind.waitCode) {
      return AuthStage.waitCode;
    }
    if (state.kind == TdAuthStateKind.waitPassword) {
      return AuthStage.waitPassword;
    }
    if (state.kind == TdAuthStateKind.ready) {
      _navigation.goToPipeline();
      return AuthStage.ready;
    }
    return AuthStage.loading;
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    reportActionError(error, title: '授权初始化失败');
  }

  void _reportTdlibError(TdlibFailure error, {required String title}) {
    _errors.reportEvent(_errorMapper.mapTdlibFailure(error, title: title));
  }

  void _reportGeneralError(Object error, {required String title}) {
    _errors.reportEvent(_errorMapper.mapGeneralError(error, title: title));
  }
}
