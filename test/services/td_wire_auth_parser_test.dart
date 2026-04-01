import 'package:flutter_test/flutter_test.dart';
import 'package:tdlib/td_api.dart';
import 'package:tgsorter/app/services/td_auth_state.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

void main() {
  group('TD wire auth parser', () {
    test('parses authorization states into local models', () {
      const codeInfo = AuthenticationCodeInfo(
        phoneNumber: '+8613800000000',
        type: AuthenticationCodeTypeTelegramMessage(length: 5),
        timeout: 60,
      );

      expect(
        TdAuthState.fromTdObject(const AuthorizationStateWaitPhoneNumber()).kind,
        TdAuthStateKind.waitPhoneNumber,
      );
      expect(
        TdAuthState.fromTdObject(
          const AuthorizationStateWaitCode(codeInfo: codeInfo),
        ).kind,
        TdAuthStateKind.waitCode,
      );
      expect(
        TdAuthState.fromTdObject(
          const AuthorizationStateWaitPassword(
            passwordHint: '',
            hasRecoveryEmailAddress: false,
            hasPassportData: false,
            recoveryEmailAddressPattern: '',
          ),
        ).kind,
        TdAuthStateKind.waitPassword,
      );
      expect(
        TdAuthState.fromTdObject(
          const AuthorizationStateWaitTdlibParameters(),
        ).kind,
        TdAuthStateKind.waitTdlibParameters,
      );
      expect(
        TdAuthState.fromTdObject(const AuthorizationStateReady()).kind,
        TdAuthStateKind.ready,
      );
      expect(
        TdAuthState.fromTdObject(const AuthorizationStateClosed()).kind,
        TdAuthStateKind.closed,
      );
    });

    test('parses connection state ready into local model', () {
      final state = TdConnectionState.fromTdObject(
        const ConnectionStateReady(),
      );

      expect(state.kind, TdConnectionStateKind.ready);
      expect(state.isReady, isTrue);
    });

    test('parses raw authorization and connection json into local models', () {
      final auth = TdAuthState.fromJson(<String, dynamic>{
        '@type': 'authorizationStateWaitTdlibParameters',
      });
      final connection = TdConnectionState.fromJson(<String, dynamic>{
        '@type': 'connectionStateReady',
      });

      expect(auth.kind, TdAuthStateKind.waitTdlibParameters);
      expect(connection.kind, TdConnectionStateKind.ready);
    });
  });
}
