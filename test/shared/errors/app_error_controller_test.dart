import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';

void main() {
  test('reportEvent stores structured error as current and history head', () {
    final controller = AppErrorController();
    final event = AppErrorEvent(
      scope: AppErrorScope.pipeline,
      level: AppErrorLevel.error,
      title: '网络异常',
      message: '请检查网络连接后重试',
    );

    controller.reportEvent(event);

    expect(controller.structuredCurrentError.value?.scope, AppErrorScope.pipeline);
    expect(controller.structuredCurrentError.value?.title, '网络异常');
    expect(controller.structuredErrorHistory.first.message, '请检查网络连接后重试');
  });
}
