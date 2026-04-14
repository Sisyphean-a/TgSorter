import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_audio.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

void main() {
  testWidgets('audio preview shows unified shell and track file actions', (
    tester,
  ) async {
    final fileActions = _RecordingPlatformFileActions();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
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
    expect(
      tester.widget<Text>(find.text('Track A')).style?.color,
      const Color(0xFF1F2329),
    );
    expect(find.text('音频已识别（点击播放开始下载）'), findsNothing);
    expect(find.text('支持播放、进度拖动、倍速和多轨切换'), findsNothing);
    expect(find.byKey(const Key('media-actions-more-menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-actions-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制路径').last);
    await tester.pumpAndSettle();

    expect(fileActions.copiedPaths, ['C:/demo/a.mp3']);
  });

  testWidgets('audio preview requests playback once and shows pending copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: const _AudioPendingHarness()),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pump();

    expect(find.text('请求:1'), findsOneWidget);
    expect(find.text('已请求播放，待音频可用后自动开始'), findsOneWidget);
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

class _AudioPendingHarness extends StatefulWidget {
  const _AudioPendingHarness();

  @override
  State<_AudioPendingHarness> createState() => _AudioPendingHarnessState();
}

class _AudioPendingHarnessState extends State<_AudioPendingHarness> {
  var _requestedMessageId = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('请求:$_requestedMessageId'),
        Expanded(
          child: MessagePreviewAudio(
            audioPath: null,
            preparing: _requestedMessageId == 1,
            onRequestPlayback: ([messageId]) async {
              setState(() {
                _requestedMessageId = messageId ?? -1;
              });
            },
            tracks: const [AudioTrackPreview(messageId: 1, title: 'Track A')],
            isPreparingTrack: (messageId) => _requestedMessageId == messageId,
          ),
        ),
      ],
    );
  }
}
