import 'package:tgsorter/app/services/td_auth_state.dart';

/// Auth feature 依赖的最小授权能力接口（capability port）。
abstract class AuthGateway {
  Stream<TdAuthState> get authStates;

  Future<void> start();
  Future<void> restart();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);
}

