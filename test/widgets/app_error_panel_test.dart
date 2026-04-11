import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_error_panel.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

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

  testWidgets('AppErrorPanel follows light theme danger palette', (tester) async {
    final controller = AppErrorController();
    controller.report(title: '运行异常', message: 'forwardMessages 失败');

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AppErrorPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();

    final panel = tester.widget<Container>(find.byKey(const Key('app-error-panel')));
    final decoration = panel.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(
      decoration.color,
      AppTokens.lightPalette.danger.withValues(alpha: 0.12),
    );
    expect(
      border.top.color,
      AppTokens.lightPalette.danger.withValues(alpha: 0.24),
    );
  });
}
