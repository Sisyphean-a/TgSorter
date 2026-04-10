import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/widgets/classification_action_group.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

void main() {
  testWidgets('empty category state keeps copy minimal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClassificationActionGroup(
            categories: [],
            enabled: true,
            onClassify: _noop,
          ),
        ),
      ),
    );

    expect(find.text('暂无分类'), findsOneWidget);
    expect(find.text('暂无分类，请先到设置页新增'), findsNothing);
  });

  testWidgets('classification actions are primary and expose shortcuts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClassificationActionGroup(
            categories: [
              CategoryConfig(
                key: 'a',
                targetChatId: 1001,
                targetChatTitle: '收纳',
              ),
              CategoryConfig(
                key: 'b',
                targetChatId: 1002,
                targetChatTitle: '归档',
              ),
            ],
            enabled: true,
            onClassify: _noop,
          ),
        ),
      ),
    );

    expect(find.text('1 收纳'), findsOneWidget);
    expect(find.text('2 归档'), findsOneWidget);
    final firstButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '1 收纳'),
    );
    final style = firstButton.style!;
    expect(style.backgroundColor?.resolve({}), AppTokens.brandAccent);
    expect(style.foregroundColor?.resolve({}), const Color(0xFF03211C));
  });
}

void _noop(String _) {}
