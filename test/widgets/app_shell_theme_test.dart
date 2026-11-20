import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/brand_app_bar.dart';
import 'package:tgsorter/app/shared/presentation/widgets/status_badge.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
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
}
