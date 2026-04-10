import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/features/pipeline/application/media_session_state.dart';
import 'package:tgsorter/app/features/pipeline/application/pipeline_screen_view_model.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

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

  testWidgets('message viewer forwards intent-level playback request', (
    tester,
  ) async {
    int? requestedId;
    final vm = MessagePreviewVm(
      content: PipelineMessage(
        id: 21,
        messageIds: const <int>[21],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.video,
          title: 'video',
          mediaItems: [
            MediaItemPreview(messageId: 21, kind: MediaItemKind.video),
          ],
        ),
      ),
      media: MediaSessionVm(
        activeItemMessageId: 21,
        items: const <int, MediaItemVm>{
          21: MediaItemVm(
            messageId: 21,
            kind: MediaItemKind.video,
            canPlay: true,
          ),
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageViewerCard(
            vm: vm,
            processing: false,
            onMediaAction: (action) async {
              if (action case OpenInApp(:final messageId)) {
                requestedId = messageId;
              }
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('message-video-play')));
    await tester.pump();

    expect(requestedId, 21);
  });

  testWidgets('vm single video shows preparing state from media session', (
    tester,
  ) async {
    final vm = MessagePreviewVm(
      content: PipelineMessage(
        id: 31,
        messageIds: const <int>[31],
        sourceChatId: 8888,
        preview: const MessagePreview(
          kind: MessagePreviewKind.video,
          title: 'single-video',
        ),
      ),
      media: MediaSessionVm(
        activeItemMessageId: 31,
        requestState: MediaRequestState.preparing,
        items: const <int, MediaItemVm>{
          31: MediaItemVm(
            messageId: 31,
            kind: MediaItemKind.video,
            playbackAvailability: MediaAvailability.preparing,
          ),
        },
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageViewerCard(
            vm: vm,
            processing: false,
            onMediaAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('视频下载中...'), findsOneWidget);
    final playButton = tester.widget<IconButton>(
      find.byKey(const Key('message-video-play')),
    );
    expect(playButton.onPressed, isNull);
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

    expect(find.text('当前消息'), findsNothing);
    expect(find.text('待分类内容预览'), findsNothing);
    expect(find.text('当前需要处理的文本消息'), findsOneWidget);
  });

  testWidgets('embedded message viewer removes decorative shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            embedded: true,
            message: PipelineMessage(
              id: 100,
              messageIds: const [100],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.text,
                title: '紧凑消息',
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const Key('message-viewer-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isEmpty);
    expect(find.text('紧凑消息'), findsOneWidget);
  });

  testWidgets('light theme uses white surface and subtle border', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 101,
              messageIds: const [101],
              sourceChatId: 100,
              preview: const MessagePreview(
                kind: MessagePreviewKind.text,
                title: '浅色消息',
              ),
            ),
            processing: false,
            videoPreparing: false,
            onRequestMediaPlayback: ([messageId]) async {},
          ),
        ),
      ),
    );

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const Key('message-viewer-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(decoration.color, const Color(0xFFFFFFFF));
    expect(border.top.color, const Color(0xFFD9E1E8));
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
    expect(find.text('暂无消息'), findsOneWidget);
    expect(find.text('收藏夹已清空，干得漂亮！'), findsNothing);
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
    expect(find.text('点击播放'), findsOneWidget);
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
                  audioTracks: [
                    AudioTrackPreview(
                      messageId: 5,
                      title: 'Song',
                      subtitle: 'Artist',
                      localAudioPath: null,
                      audioDurationSeconds: 180,
                    ),
                  ],
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

  testWidgets('link preview renders lean article preview', (tester) async {
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
    expect(find.byKey(const ValueKey('media-action-打开链接')), findsOneWidget);
    expect(find.text('展开详情'), findsNothing);
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
    expect(find.text('音频列表'), findsNothing);
    expect(find.text('Track A'), findsOneWidget);
    expect(find.text('Track B'), findsOneWidget);
  });

  testWidgets('audio album does not render redundant group title text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 79,
              messageIds: const [79, 80],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.audio,
                title: '音频组 (2 条)',
                audioTracks: const [
                  AudioTrackPreview(
                    messageId: 79,
                    title: 'Track A',
                    localAudioPath: null,
                  ),
                  AudioTrackPreview(
                    messageId: 80,
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

    expect(find.text('音频组 (2 条)'), findsNothing);
  });

  testWidgets('photo preview renders unified image gallery shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 66,
              messageIds: const [66],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.photo,
                title: '[图片]',
                mediaItems: const [
                  MediaItemPreview(
                    messageId: 66,
                    kind: MediaItemKind.photo,
                    previewPath: null,
                    fullPath: null,
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

    expect(find.text('图片预览'), findsNothing);
    expect(find.byKey(const ValueKey('media-action-查看大图')), findsOneWidget);
    expect(find.text('点击进入大图预览'), findsNothing);
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
    expect(find.text('00:11'), findsOneWidget);
    expect(find.text('00:22'), findsOneWidget);
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('video mosaic keeps playback chrome lightweight', (tester) async {
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

    final playButton = tester.widget<IconButton>(
      find.byKey(const Key('message-video-play')).first,
    );
    final firstTile = tester.getTopLeft(
      find.byKey(const ValueKey('message-preview-media-tile-6')),
    );
    final firstDuration = tester.getTopLeft(find.textContaining('00:11'));

    expect(playButton.style?.backgroundColor?.resolve({}), Colors.transparent);
    expect(find.text('00:11'), findsOneWidget);
    expect(find.text('时长 00:11'), findsNothing);
    expect(firstDuration.dx - firstTile.dx, lessThan(16));
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

    expect(find.text('00:11'), findsNWidgets(2));
    expect(find.text('时长 00:11'), findsNothing);
  });

  testWidgets('mixed media group renders all tiles without carousel', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 81,
              messageIds: const [81, 82, 83],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.video,
                title: '媒体组 (3 项)',
                mediaItems: const [
                  MediaItemPreview(
                    messageId: 81,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                  ),
                  MediaItemPreview(
                    messageId: 82,
                    kind: MediaItemKind.photo,
                    previewPath: null,
                    fullPath: null,
                  ),
                  MediaItemPreview(
                    messageId: 83,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
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

    expect(find.byType(PageView), findsNothing);
    expect(
      find.byKey(const ValueKey('message-preview-media-tile-81')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('message-preview-media-tile-82')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('message-preview-media-tile-83')),
      findsOneWidget,
    );
  });

  testWidgets('grouped video preparing spinner is scoped to selected item', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: MessageViewerCard(
            message: PipelineMessage(
              id: 91,
              messageIds: const [91, 92],
              sourceChatId: 100,
              preview: MessagePreview(
                kind: MessagePreviewKind.video,
                title: '媒体组 (2 项)',
                mediaItems: const [
                  MediaItemPreview(
                    messageId: 91,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                  ),
                  MediaItemPreview(
                    messageId: 92,
                    kind: MediaItemKind.video,
                    previewPath: null,
                    fullPath: null,
                  ),
                ],
              ),
            ),
            processing: false,
            videoPreparing: true,
            onRequestMediaPlayback: ([messageId]) async {},
            isMediaPreparing: (messageId) => messageId == 91,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
