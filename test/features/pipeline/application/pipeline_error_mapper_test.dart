import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_error_mapper.dart';
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
  });
}
