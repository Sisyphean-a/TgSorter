import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_actions.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_shell.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

void main() {
  testWidgets('media shell renders primary and more actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageMediaShell(
            header: const Text('Header'),
            actions: [
              MessageMediaAction(
                icon: Icons.fullscreen_rounded,
                label: '全屏',
                onPressed: (_) async {},
              ),
            ],
            moreActions: [
              MessageMediaAction(
                icon: Icons.copy_rounded,
                label: '复制路径',
                onPressed: (_) async {},
              ),
            ],
            child: const SizedBox(height: 100),
          ),
        ),
      ),
    );

    expect(find.text('Header'), findsOneWidget);
    expect(find.byKey(const ValueKey('media-action-全屏')), findsOneWidget);
    expect(find.byKey(const Key('media-actions-more-menu')), findsOneWidget);
  });

  test('platform file actions expose expected capabilities', () {
    const actions = PlatformFileActions();

    expect(actions.canOpenFile('C:/video.mp4'), isTrue);
    expect(actions.canCopyPath('C:/video.mp4'), isTrue);
    expect(actions.canOpenFile(null), isFalse);
    expect(actions.canOpenUrl('https://openai.com'), isTrue);
    expect(actions.canOpenUrl('not a url'), isFalse);
  });
}
