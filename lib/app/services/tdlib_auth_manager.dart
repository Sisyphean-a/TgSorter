import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/services/tdlib_request_executor.dart';

class TdlibAuthManager {
  const TdlibAuthManager({required TdlibRequestExecutor requestExecutor})
    : _requestExecutor = requestExecutor;

  static const Duration authRequestTimeout = Duration(minutes: 2);

  final TdlibRequestExecutor _requestExecutor;

  Future<void> submitPhoneNumber(String phoneNumber) {
    return _requestExecutor.sendWireExpectOk(
      SetAuthenticationPhoneNumber(phoneNumber: phoneNumber),
      request: 'setAuthenticationPhoneNumber',
      phase: TdlibPhase.auth,
      timeout: authRequestTimeout,
    );
  }

  Future<void> submitCode(String code) {
    return _requestExecutor.sendWireExpectOk(
      CheckAuthenticationCode(code: code),
      request: 'checkAuthenticationCode',
      phase: TdlibPhase.auth,
      timeout: authRequestTimeout,
    );
  }

  Future<void> submitPassword(String password) {
    return _requestExecutor.sendWireExpectOk(
      CheckAuthenticationPassword(password: password),
      request: 'checkAuthenticationPassword',
      phase: TdlibPhase.auth,
      timeout: authRequestTimeout,
    );
  }
}
