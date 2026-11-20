import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/core/routing/navigator_auth_navigation_adapter.dart';

void main() {
  testWidgets(
    'auth waits stay on the same page; login and logout clear history',
    (tester) async {
      final navigation = NavigatorAuthNavigationAdapter();
      await _pumpApp(tester, navigation);
      final authPage = tester.element(find.text('auth page'));

      navigation.goToAuth();
      await tester.pumpAndSettle();
      expect(tester.element(find.text('auth page')), same(authPage));

      navigation.goToApp();
      navigation.goToApp();
      await tester.pumpAndSettle();
      expect(find.text('app page'), findsOneWidget);
      expect(navigation.key.currentState!.canPop(), isFalse);

      navigation.goToAuth();
      await tester.pumpAndSettle();
      expect(find.text('auth page'), findsOneWidget);
      expect(navigation.key.currentState!.canPop(), isFalse);
    },
  );

  testWidgets('session ready before the app mounts opens the workbench', (
    tester,
  ) async {
    final navigation = NavigatorAuthNavigationAdapter()..goToApp();
    await _pumpApp(tester, navigation);

    expect(find.text('app page'), findsOneWidget);
    expect(navigation.key.currentState!.canPop(), isFalse);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  NavigatorAuthNavigationAdapter navigation,
) => tester.pumpWidget(
  MaterialApp(
    navigatorKey: navigation.key,
    navigatorObservers: [navigation],
    initialRoute: navigation.initialRoute,
    routes: {
      AppRoutes.auth: (_) => const Scaffold(body: Text('auth page')),
      AppRoutes.app: (_) => const Scaffold(body: Text('app page')),
    },
  ),
);
