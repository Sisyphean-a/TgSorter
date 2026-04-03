import 'package:tgsorter/app/services/td_auth_state.dart';

abstract class AuthGateway {
  Stream<TdAuthState> get authStates;

  Future<void> start();
  Future<void> restart();
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitCode(String code);
  Future<void> submitPassword(String password);
}
