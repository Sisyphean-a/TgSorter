import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';

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

  testWidgets('renders workspace header above current message content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 99,
              messageIds: const [99],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.text,
                title: '当前需要处理的文本消息',
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(find.text('当前消息'), findsOneWidget);
    expect(find.text('待分类内容预览'), findsOneWidget);
  });

  testWidgets('renders empty state inside dedicated preview shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: null,
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('message-preview-empty-state')),
      findsOneWidget,
    );
    expect(find.text('收藏夹已清空，干得漂亮！'), findsOneWidget);
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

  testWidgets('link preview renders dedicated link card shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 55,
              messageIds: const [55],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.text,
                title: 'OpenAI',
                linkCard: LinkCardPreview(
                  url: 'https://openai.com',
                  displayUrl: 'openai.com',
                  siteName: 'OpenAI',
                  title: 'OpenAI',
                  description: 'AI research and products',
                ),
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('message-preview-link-card')), findsOneWidget);
    expect(find.text('AI research and products'), findsOneWidget);
  });

  testWidgets('audio album keeps a dedicated track list container', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 77,
              messageIds: const [77, 78],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.audio,
                title: '合集',
                audioTracks: const [
                  AudioTrackPreview(
                    messageId: 77,
                    title: 'Track A',
                    localAudioPath: null,
                  ),
                  AudioTrackPreview(
                    messageId: 78,
                    title: 'Track B',
                    localAudioPath: null,
                  ),
                ],
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('message-preview-audio-tracks')),
      findsOneWidget,
    );
    expect(find.text('Track A'), findsOneWidget);
    expect(find.text('Track B'), findsOneWidget);
  });

  testWidgets('video group shows all video items instead of a single page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 6,
              messageIds: const [6, 7],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.video,
                title: '媒体组 (2 项)',
                mediaItems: const [
                  MediaItemPreview(
                    messageId: 6,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                    durationSeconds: 11,
                  ),
                  MediaItemPreview(
                    messageId: 7,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                    durationSeconds: 22,
                  ),
                ],
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
    expect(find.text('时长 00:11'), findsOneWidget);
    expect(find.text('时长 00:22'), findsOneWidget);
  });

  testWidgets('video group does not duplicate duration text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 8,
              messageIds: const [8, 9],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.video,
                title: '媒体组 (2 项)',
                videoDurationSeconds: 11,
                mediaItems: const [
                  MediaItemPreview(
                    messageId: 8,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                    durationSeconds: 11,
                  ),
                  MediaItemPreview(
                    messageId: 9,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                    durationSeconds: 11,
                  ),
                ],
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    expect(find.text('时长 00:11'), findsNWidgets(2));
  });
}
