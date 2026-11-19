import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

class AuthErrorMapper {
  const AuthErrorMapper();

  AppErrorEvent mapTdlibFailure(TdlibFailure error, {required String title}) {
    final message = switch (error.message.trim().toUpperCase()) {
      'PASSWORD_HASH_INVALID' => 'Telegram 两步验证密码不正确。它不是短信验证码，也不是手机解锁密码。',
      'PHONE_CODE_INVALID' => '验证码不正确，请核对 Telegram 发来的最新验证码。',
      'PHONE_CODE_EXPIRED' => '验证码已过期，请重新获取验证码。',
      'PHONE_NUMBER_INVALID' => '手机号无效。请确认号码包含国际区号，例如 +86。',
      _ => null,
    };
    if (error.kind == TdlibFailureKind.tdlib && message != null) {
      return _authError(title: title, message: message);
    }
    if (error.kind == TdlibFailureKind.timeout) {
      return _authError(
        title: title,
        message: '等待 Telegram 响应超时。请检查网络和系统 VPN，再重试。',
      );
    }
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，请等待 $waitSeconds 秒';
      return _authError(title: title, message: '触发 FloodWait$suffix');
    }
    if (kind == TdErrorKind.network) {
      return _authError(title: title, message: '网络异常：${error.message}');
    }
    if (kind == TdErrorKind.auth) {
      return _authError(title: title, message: '鉴权失败：${error.message}');
    }
    if (kind == TdErrorKind.permission) {
      return _authError(title: title, message: '权限受限，请检查 Telegram 账号状态');
    }
    return _authError(title: title, message: error.toString());
  }

  AppErrorEvent mapGeneralError(Object error, {required String title}) {
    return _authError(title: title, message: error.toString());
  }

  AppErrorEvent _authError({required String title, required String message}) {
    return AppErrorEvent(
      scope: AppErrorScope.auth,
      level: AppErrorLevel.error,
      title: title,
      message: message,
    );
  }
}
