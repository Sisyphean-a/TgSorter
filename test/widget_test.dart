import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/bootstrap_app.dart';

void main() {
  testWidgets('shows bootstrap loading while init is pending', (
    WidgetTester tester,
  ) async {
    final pendingInit = Completer<void>();
    await tester.pumpWidget(BootstrapApp(init: () => pendingInit.future));

    expect(find.text('正在初始化...'), findsOneWidget);
  });
}
