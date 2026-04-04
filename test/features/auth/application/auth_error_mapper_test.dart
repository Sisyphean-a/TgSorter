import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/auth/application/auth_error_mapper.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

void main() {
  const mapper = AuthErrorMapper();

  test('maps flood wait failure to auth-scoped retry message', () {
    final event = mapper.mapTdlibFailure(
      TdlibFailure.tdError(
        code: 420,
        message: 'FLOOD_WAIT_17',
        request: 'checkAuthenticationCode',
        phase: TdlibPhase.auth,
      ),
      title: '提交验证码失败',
    );

    expect(event.scope, AppErrorScope.auth);
    expect(event.title, '提交验证码失败');
    expect(event.message, '触发 FloodWait，请等待 17 秒');
  });

  test('maps permission failure to account status hint', () {
    final event = mapper.mapTdlibFailure(
      TdlibFailure.tdError(
        code: 403,
        message: 'CHAT_WRITE_FORBIDDEN',
        request: 'setAuthenticationPhoneNumber',
        phase: TdlibPhase.auth,
      ),
      title: '发送验证码失败',
    );

    expect(event.scope, AppErrorScope.auth);
    expect(event.title, '发送验证码失败');
    expect(event.message, '权限受限，请检查 Telegram 账号状态');
  });

  test('maps general errors to auth-scoped runtime message', () {
    final event = mapper.mapGeneralError(
      StateError('bad state'),
      title: '启动失败',
    );

    expect(event.scope, AppErrorScope.auth);
    expect(event.title, '启动失败');
    expect(event.message, 'Bad state: bad state');
  });
}
