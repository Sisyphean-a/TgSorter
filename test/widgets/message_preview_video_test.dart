import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_video.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

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

    expect(find.text('视频预览'), findsOneWidget);
    expect(find.text('支持全屏、倍速、循环和文件动作'), findsOneWidget);
    expect(find.text('点击播放后可进入更完整的预览与控制'), findsOneWidget);
    expect(find.byKey(const Key('media-actions-more-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-actions-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制路径').last);
    await tester.pumpAndSettle();

    expect(fileActions.copiedPaths, ['C:/demo/video.mp4']);
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
