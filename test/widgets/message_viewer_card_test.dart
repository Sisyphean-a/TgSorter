import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/widgets/message_viewer_card.dart';

void main() {
  testWidgets('video preview shows play action before local file is ready', (
    tester,
  ) async {
    var playRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 1,
              messageIds: const [1],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.video,
                title: '[视频]',
                localVideoThumbnailPath: null,
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {
              playRequests++;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(playRequests, 1);
  });

  testWidgets('uses high contrast text color on dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 2,
              messageIds: const [2],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.video,
                title: '#REDPMV 005 高跟鞋',
                videoDurationSeconds: 688,
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('#REDPMV 005 高跟鞋'));
    final duration = tester.widget<Text>(find.text('时长 11:28'));

    expect(title.style?.color, isNot(Colors.black));
    expect(duration.style?.color, isNot(Colors.black54));
  });

  testWidgets('does not enter loading state for incomplete local video file', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 3,
              messageIds: const [3],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.video,
                title: '[视频]',
                localVideoPath: null,
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(find.text('视频加载中...'), findsNothing);
    expect(find.text('视频已识别（点击播放开始下载）'), findsOneWidget);
  });

  testWidgets(
    'shows play button instead of auto loading for ready local video',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MessageViewerCard(
              message: PipelineMessage(
                id: 4,
                messageIds: const [4],
                sourceChatId: 100,
                preview: const MessagePreview(
                  kind: MessagePreviewKind.video,
                  title: '[视频]',
                  localVideoPath: 'C:/ready.mp4',
                  localVideoThumbnailPath: 'C:/thumb.jpg',
                ),
              ),
              processing: false,
              videoPreparing: false,
              onRequestMediaPlayback: ([messageId]) async {},
            ),
          ),
        ),
      );

      expect(find.text('视频加载中...'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'audio preview shows download/play action before local file is ready',
    (tester) async {
      var playRequests = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MessageViewerCard(
              message: PipelineMessage(
                id: 5,
                messageIds: const [5],
                sourceChatId: 100,
                preview: const MessagePreview(
                  kind: MessagePreviewKind.audio,
                  title: 'Song',
                  subtitle: 'Artist',
                  localAudioPath: null,
                  audioDurationSeconds: 180,
                ),
              ),
              processing: false,
              videoPreparing: false,
              onRequestMediaPlayback: ([messageId]) async {
                playRequests++;
              },
            ),
          ),
        ),
      );

      expect(find.text('Song'), findsOneWidget);
      expect(find.text('Artist'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(playRequests, 1);
    },
  );
}
