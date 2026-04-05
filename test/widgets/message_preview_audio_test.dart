import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_audio.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

void main() {
  testWidgets('audio preview shows unified shell and track file actions', (
    tester,
  ) async {
    final fileActions = _RecordingPlatformFileActions();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagePreviewAudio(
            audioPath: 'C:/demo/a.mp3',
            preparing: false,
            onRequestPlayback: ([messageId]) async {},
            tracks: const [
              AudioTrackPreview(
                messageId: 1,
                title: 'Track A',
                localAudioPath: 'C:/demo/a.mp3',
                audioDurationSeconds: 180,
              ),
              AudioTrackPreview(
                messageId: 2,
                title: 'Track B',
                localAudioPath: 'C:/demo/b.mp3',
                audioDurationSeconds: 240,
              ),
            ],
            fileActions: fileActions,
          ),
        ),
      ),
    );

    expect(find.text('音频列表'), findsNothing);
    expect(find.text('支持多轨切换和倍速'), findsNothing);
    expect(find.text('Track A'), findsOneWidget);
    expect(find.text('Track B'), findsOneWidget);
    expect(find.text('支持播放、进度拖动、倍速和多轨切换'), findsNothing);
    expect(find.byKey(const Key('media-actions-more-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-actions-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制路径').last);
    await tester.pumpAndSettle();

    expect(fileActions.copiedPaths, ['C:/demo/a.mp3']);
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
