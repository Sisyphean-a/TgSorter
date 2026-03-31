import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/widgets/pipeline_layout_switch.dart';

void main() {
  group('PipelineLayoutSwitch', () {
    testWidgets('renders desktop child on wide layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PipelineLayoutSwitch(
              mobile: const SizedBox(key: Key('mobile-layout')),
              desktop: const SizedBox(key: Key('desktop-layout')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('desktop-layout')), findsOneWidget);
      expect(find.byKey(const Key('mobile-layout')), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders mobile child on narrow layout', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 800));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PipelineLayoutSwitch(
              mobile: const SizedBox(key: Key('mobile-layout')),
              desktop: const SizedBox(key: Key('desktop-layout')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('mobile-layout')), findsOneWidget);
      expect(find.byKey(const Key('desktop-layout')), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });
  });
}
