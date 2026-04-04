import 'package:tgsorter/app/features/auth/ports/auth_navigation_port.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';

enum AuthStage {
  loading,
  waitPhone,
  waitCode,
  waitPassword,
  ready,
  unsupported,
}

class AuthLifecycleCoordinator {
  AuthLifecycleCoordinator(this._navigation);

  final AuthNavigationPort _navigation;

  AuthStage handle(TdAuthState state) {
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
}
