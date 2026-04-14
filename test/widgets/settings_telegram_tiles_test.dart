import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets('value tile keeps long trailing value on one line', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsValueTile(
            title: '转发来源会话',
            value: '收藏夹（Saved Messages）',
            onTap: () {},
          ),
        ),
      ),
    );

    final valueText = tester.widget<Text>(
      find.text('收藏夹（Saved Messages）'),
    );
    expect(valueText.maxLines, 1);
    expect(valueText.textAlign, TextAlign.end);
    expect(valueText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('switch tile keeps title block and switch aligned', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsSwitchTile(
            title: '无引用转发',
            subtitle: '开启后转发结果不携带原始引用关系',
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(Switch), findsOneWidget);
    final titleText = tester.widget<Text>(find.text('无引用转发'));
    expect(titleText.maxLines, 2);
  });
}
