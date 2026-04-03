import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';

void main() {
  testWidgets('AppErrorPanel keeps reported errors visible', (tester) async {
    final controller = AppErrorController();
    controller.report(title: '运行异常', message: 'TDLib 授权未就绪，无法执行当前请求');

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppErrorPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('错误历史'), findsOneWidget);
    expect(find.textContaining('TDLib 授权未就绪'), findsOneWidget);
    expect(find.byKey(const Key('app-error-panel')), findsOneWidget);
  });
}
