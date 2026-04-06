import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/widgets/classification_action_group.dart';

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
}

void _noop(String _) {}
