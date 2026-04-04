import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

class AuthErrorMapper {
  const AuthErrorMapper();

  AppErrorEvent mapTdlibFailure(TdlibFailure error, {required String title}) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，请等待 $waitSeconds 秒';
      return _authError(
        title: title,
        message: '触发 FloodWait$suffix',
      );
    }
    if (kind == TdErrorKind.network) {
      return _authError(
        title: title,
        message: '网络异常：${error.message}',
      );
    }
    if (kind == TdErrorKind.auth) {
      return _authError(
        title: title,
        message: '鉴权失败：${error.message}',
      );
    }
    if (kind == TdErrorKind.permission) {
      return _authError(
        title: title,
        message: '权限受限，请检查 Telegram 账号状态',
      );
    }
    return _authError(
      title: title,
      message: error.toString(),
    );
  }

  AppErrorEvent mapGeneralError(Object error, {required String title}) {
    return _authError(
      title: title,
      message: error.toString(),
    );
  }

  AppErrorEvent _authError({
    required String title,
    required String message,
  }) {
    return AppErrorEvent(
      scope: AppErrorScope.auth,
      level: AppErrorLevel.error,
      title: title,
      message: message,
    );
  }
}
