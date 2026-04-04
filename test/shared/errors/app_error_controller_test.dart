import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

void main() {
  test('reportEvent keeps legacy and structured current in sync', () {
    final controller = AppErrorController();
    final event = AppErrorEvent(
      scope: AppErrorScope.pipeline,
      level: AppErrorLevel.error,
      title: '网络异常',
      message: '请检查网络连接后重试',
    );

    controller.reportEvent(event);

    expect(controller.structuredCurrentError.value, event);
    expect(controller.currentError.value, formatAppErrorEvent(event));
    expect(controller.errorHistory.first, formatAppErrorEvent(event));
    expect(controller.structuredErrorHistory.first, event);
  });

  test('clearCurrent only removes current states', () {
    final controller = AppErrorController();
    final event = AppErrorEvent(
      scope: AppErrorScope.pipeline,
      level: AppErrorLevel.error,
      title: '网络异常',
      message: '请检查网络连接后重试',
    );

    controller.reportEvent(event);
    controller.clearCurrent();

    expect(controller.structuredCurrentError.value, isNull);
    expect(controller.currentError.value, isNull);
    expect(controller.errorHistory.first, formatAppErrorEvent(event));
    expect(controller.structuredErrorHistory.first, event);
  });
}
