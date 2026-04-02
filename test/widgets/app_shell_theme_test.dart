import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';
import 'package:tgsorter/app/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/widgets/status_badge.dart';

void main() {
  test('app theme uses dark branded palette', () {
    final theme = AppTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppTokens.pageBackground);
    expect(theme.colorScheme.primary, AppTokens.brandAccent);
    expect(theme.colorScheme.surface, AppTokens.surfaceBase);
    expect(theme.useMaterial3, isTrue);
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.dialogTheme.backgroundColor, AppTokens.panelBackground);
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
  });

  testWidgets('brand app bar renders headline and status badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          appBar: BrandAppBar(
            title: 'TgSorter',
            subtitle: '分类工作台',
            badges: const [
              StatusBadge(label: '在线', tone: StatusBadgeTone.success),
              StatusBadge(label: '剩余 32', tone: StatusBadgeTone.accent),
            ],
          ),
        ),
      ),
    );

    expect(find.text('TgSorter'), findsOneWidget);
    expect(find.text('分类工作台'), findsOneWidget);
    expect(find.byType(StatusBadge), findsNWidgets(2));
    expect(find.byType(AppBar), findsNothing);
  });
}
