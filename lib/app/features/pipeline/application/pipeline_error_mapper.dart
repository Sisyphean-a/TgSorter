import 'package:tgsorter/app/domain/flood_wait.dart';
import 'package:tgsorter/app/domain/td_error_classifier.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

class PipelineResolvedError {
  const PipelineResolvedError({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class PipelineErrorMapper {
  const PipelineErrorMapper();

  PipelineResolvedError mapTdlibFailure(TdlibFailure error) {
    final kind = classifyTdlibError(error);
    if (kind == TdErrorKind.rateLimit) {
      final waitSeconds = parseFloodWaitSeconds(error.message);
      final suffix = waitSeconds == null ? '' : '，需等待 $waitSeconds 秒';
      return PipelineResolvedError(
        title: '操作过快',
        message: '触发 FloodWait$suffix',
      );
    }
    if (kind == TdErrorKind.network) {
      return const PipelineResolvedError(
        title: '网络异常',
        message: '请检查网络连接后重试',
      );
    }
    if (kind == TdErrorKind.auth) {
      return const PipelineResolvedError(
        title: '鉴权异常',
        message: '登录态可能失效，请重新登录',
      );
    }
    if (kind == TdErrorKind.permission) {
      return const PipelineResolvedError(
        title: '权限异常',
        message: '目标会话可能无发送权限',
      );
    }
    return PipelineResolvedError(
      title: 'TDLib 错误',
      message: error.toString(),
    );
  }

  PipelineResolvedError mapGeneralError(Object error) {
    return PipelineResolvedError(
      title: '运行异常',
      message: error.toString(),
    );
  }
}
