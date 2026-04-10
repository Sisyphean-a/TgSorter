import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/widgets/mobile_action_tray.dart';

void main() {
  testWidgets('mobile action tray follows light theme palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MobileActionTray(
            categories: const [],
            canClick: false,
            online: true,
            onClassify: (_) {},
            secondaryActions: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    final tray = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(MobileActionTray),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = tray.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final emptyText = tester.widget<Text>(find.text('暂无分类'));

    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(border.top.color, const Color(0xFFD9E1E8));
    expect(emptyText.style?.color, const Color(0xFF74808B));
    expect(decoration.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('mobile category button follows light action color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MobileActionTray(
            categories: const [
              CategoryConfig(key: 'a', targetChatId: 1, targetChatTitle: '收纳'),
            ],
            canClick: true,
            online: true,
            onClassify: (_) {},
            secondaryActions: const SizedBox.shrink(),
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '收纳'),
    );

    expect(button.style?.backgroundColor?.resolve({}), const Color(0xFF3390EC));
    expect(button.style?.foregroundColor?.resolve({}), const Color(0xFFFFFFFF));
  });
}
