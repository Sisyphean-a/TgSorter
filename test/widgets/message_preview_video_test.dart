import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_video.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_video_fullscreen.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets('video preview shows richer shell and file actions hint', (
    tester,
  ) async {
    final fileActions = _RecordingPlatformFileActions();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagePreviewVideo(
            videoPath: 'C:/demo/video.mp4',
            thumbnailPath: null,
            preparing: false,
            onRequestPlayback: ([messageId]) async {},
            controllerInitializer: null,
            fileActions: fileActions,
          ),
        ),
      ),
    );

    expect(find.text('视频预览'), findsNothing);
    expect(find.text('支持全屏、倍速、循环和文件动作'), findsNothing);
    expect(find.text('点击播放后可进入更完整的预览与控制'), findsNothing);
    expect(find.text('静音'), findsNothing);
    expect(find.byKey(const Key('media-actions-more-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-actions-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制路径').last);
    await tester.pumpAndSettle();

    expect(fileActions.copiedPaths, ['C:/demo/video.mp4']);
  });

  test('preferred orientations follow video aspect ratio', () {
    expect(
      preferredOrientationsForVideoAspectRatio(16 / 9),
      const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
    expect(
      preferredOrientationsForVideoAspectRatio(9 / 16),
      const <DeviceOrientation>[
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ],
    );
  });

  testWidgets('video placeholder is readable in light theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: PreviewPlaceholder(text: '点击播放')),
      ),
    );

    final placeholder = tester.widget<Container>(find.byType(Container).first);
    final label = tester.widget<Text>(find.text('点击播放'));

    expect(placeholder.color, const Color(0xFFF8FAFC));
    expect(label.style?.color, const Color(0xFF74808B));
  });

  testWidgets('adaptive fullscreen locks and restores orientations', (
    tester,
  ) async {
    final orientationCalls = <List<dynamic>>[];
    late BuildContext launchContext;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientationCalls.add(List<dynamic>.from(call.arguments as List));
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            launchContext = context;
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showAdaptiveVideoFullscreenDialog<void>(
                    context: context,
                    aspectRatio: 16 / 9,
                    builder: (_) => const SizedBox.expand(
                      child: ColoredBox(color: Colors.black),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(orientationCalls.first, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    Navigator.of(launchContext, rootNavigator: true).pop();
    await tester.pumpAndSettle();

    expect(orientationCalls.last, isEmpty);
  });
}

class _RecordingPlatformFileActions extends PlatformFileActions {
  final List<String> copiedPaths = <String>[];

  @override
  bool canRevealInFolder(String? path) {
    return false;
  }

  @override
  Future<void> copyPath(BuildContext context, String path) async {
    copiedPaths.add(path);
  }
}
