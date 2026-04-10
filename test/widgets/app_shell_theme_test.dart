import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/app_shell.dart';
import 'package:tgsorter/app/theme/app_theme.dart';
import 'package:tgsorter/app/shared/presentation/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';

void main() {
  test('app theme uses light telegram-inspired palette by default', () {
    final theme = AppTheme.light();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF4F5F7));
    expect(theme.colorScheme.primary, const Color(0xFF3390EC));
    expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(theme.useMaterial3, isTrue);
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.dialogTheme.backgroundColor, const Color(0xFFFFFFFF));
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
  });

  test('app theme uses neutral dark palette', () {
    final theme = AppTheme.dark();

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF17191C));
    expect(theme.colorScheme.primary, const Color(0xFF5CA8F5));
    expect(theme.colorScheme.surface, const Color(0xFF23262A));
    expect(theme.useMaterial3, isTrue);
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.dialogTheme.backgroundColor, const Color(0xFF23262A));
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

  testWidgets('brand app bar follows light theme palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          appBar: BrandAppBar(title: 'TgSorter', subtitle: '安全登录'),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(BrandAppBar),
        matching: find.byType(Material),
      ),
    );
    final headerBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(BrandAppBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = headerBox.decoration as BoxDecoration;

    expect(material.color, const Color(0xFFF4F5F7));
    expect(decoration.color, const Color(0xFFFFFFFF));
  });

  testWidgets('brand app bar follows dark theme palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          appBar: BrandAppBar(title: 'TgSorter', subtitle: '安全登录'),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(BrandAppBar),
        matching: find.byType(Material),
      ),
    );
    final headerBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(BrandAppBar),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = headerBox.decoration as BoxDecoration;

    expect(material.color, const Color(0xFF17191C));
    expect(decoration.color, const Color(0xFF23262A));
  });

  testWidgets('brand app bar stays stable on narrow mobile width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          appBar: BrandAppBar(
            title: 'TgSorter',
            subtitle: '分类工作台',
            badges: const [
              StatusBadge(label: '离线', tone: StatusBadgeTone.danger),
              StatusBadge(label: '待命', tone: StatusBadgeTone.neutral),
              StatusBadge(label: '剩余 -', tone: StatusBadgeTone.accent),
            ],
            actions: const [
              IconButton(onPressed: null, icon: Icon(Icons.tune_rounded)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TgSorter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app shell uses flat theme-driven background in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AppShell(body: SizedBox.expand()),
      ),
    );

    final shellBox = tester.widget<DecoratedBox>(
      find.byType(DecoratedBox).first,
    );
    final decoration = shellBox.decoration as BoxDecoration;

    expect(decoration.gradient, isNull);
    expect(decoration.color, const Color(0xFFF4F5F7));
  });

  testWidgets('status badge uses light accent palette in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: StatusBadge(label: '剩余 32', tone: StatusBadgeTone.accent),
          ),
        ),
      ),
    );

    final badgeBox = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
    final decoration = badgeBox.decoration as BoxDecoration;
    final label = tester.widget<Text>(find.text('剩余 32'));

    expect(decoration.color, const Color(0xFFE9F3FF));
    expect(label.style?.color, const Color(0xFF3390EC));
  });
}
