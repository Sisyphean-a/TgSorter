import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_error_mapper.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';
import 'package:tgsorter/app/services/tdlib_failure.dart';

void main() {
  test('maps flood wait to user-facing fast-operation message', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapTdlibFailure(
      TdlibFailure.tdError(
        code: 429,
        message: 'FLOOD_WAIT_17',
        request: 'classify',
        phase: TdlibPhase.business,
      ),
    );

    expect(resolved.title, '操作过快');
    expect(resolved.message, contains('17'));
    expect(resolved.scope, AppErrorScope.pipeline);
    expect(resolved.level, AppErrorLevel.error);
  });

  test('maps network failure to stable offline copy', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapTdlibFailure(
      TdlibFailure.transport(
        message: 'NETWORK_ERROR',
        request: 'fetch',
        phase: TdlibPhase.business,
      ),
    );

    expect(resolved.title, '网络异常');
    expect(resolved.message, '请检查网络连接后重试');
    expect(resolved.scope, AppErrorScope.pipeline);
    expect(resolved.level, AppErrorLevel.error);
  });

  test('maps auth failure to re-login guidance', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapTdlibFailure(
      TdlibFailure.tdError(
        code: 401,
        message: 'AUTH_KEY_INVALID',
        request: 'auth',
        phase: TdlibPhase.auth,
      ),
    );

    expect(resolved.title, '鉴权异常');
    expect(resolved.message, '登录态可能失效，请重新登录');
    expect(resolved.scope, AppErrorScope.pipeline);
    expect(resolved.level, AppErrorLevel.error);
  });

  test('maps permission failure to target permission guidance', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapTdlibFailure(
      TdlibFailure.tdError(
        code: 403,
        message: 'CHAT_WRITE_FORBIDDEN',
        request: 'classify',
        phase: TdlibPhase.business,
      ),
    );

    expect(resolved.title, '权限异常');
    expect(resolved.message, '目标会话可能无发送权限');
    expect(resolved.scope, AppErrorScope.pipeline);
    expect(resolved.level, AppErrorLevel.error);
  });

  test('maps unexpected tdlib failure to generic tdlib message', () {
    final mapper = PipelineErrorMapper();

    final failure = TdlibFailure.tdError(
      code: 500,
      message: 'UNKNOWN',
      request: 'fetch',
      phase: TdlibPhase.business,
    );
    final resolved = mapper.mapTdlibFailure(failure);

    expect(resolved.title, 'TDLib 错误');
    expect(resolved.message, failure.toString());
    expect(resolved.scope, AppErrorScope.pipeline);
    expect(resolved.level, AppErrorLevel.error);
  });

  test('maps general error to runtime message', () {
    final mapper = PipelineErrorMapper();

    final resolved = mapper.mapGeneralError(StateError('boom'));

    expect(resolved.title, '运行异常');
    expect(resolved.message, 'Bad state: boom');
    expect(resolved.scope, AppErrorScope.pipeline);
    expect(resolved.level, AppErrorLevel.error);
  });
}
