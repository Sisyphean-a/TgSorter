import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

class PipelineErrorMapper {
  const PipelineErrorMapper();

  AppErrorEvent mapTdlibFailure(TdlibFailure error) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，需等待 $waitSeconds 秒';
      return _pipelineError(
        title: '操作过快',
        message: '触发 FloodWait$suffix',
      );
    }
    if (kind == TdErrorKind.network) {
      return _pipelineError(
        title: '网络异常',
        message: '请检查网络连接后重试',
      );
    }
    if (kind == TdErrorKind.auth) {
      return _pipelineError(
        title: '鉴权异常',
        message: '登录态可能失效，请重新登录',
      );
    }
    if (kind == TdErrorKind.permission) {
      return _pipelineError(
        title: '权限异常',
        message: '目标会话可能无发送权限',
      );
    }
    return _pipelineError(
      title: 'TDLib 错误',
      message: error.toString(),
    );
  }

  AppErrorEvent mapGeneralError(Object error) {
    return _pipelineError(
      title: '运行异常',
      message: error.toString(),
    );
  }

  AppErrorEvent _pipelineError({
    required String title,
    required String message,
  }) {
    return AppErrorEvent(
      scope: AppErrorScope.pipeline,
      level: AppErrorLevel.error,
      title: title,
      message: message,
    );
  }
}
