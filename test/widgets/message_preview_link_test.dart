import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/models/pipeline_message.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_link.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_viewer_card.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

void main() {
  testWidgets('link preview exposes external open action only', (tester) async {
    final fileActions = _RecordingPlatformFileActions();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagePreviewLinkCard(
            link: const LinkCardPreview(
              url: 'https://openai.com/research',
              displayUrl: 'openai.com/research',
              siteName: 'OpenAI',
              title: 'Research',
              description: 'Latest AI research updates',
            ),
            fileActions: fileActions,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('message-preview-link-card')), findsOneWidget);
    expect(find.text('展开详情'), findsNothing);
    expect(find.text('完整链接'), findsNothing);
    expect(find.text('外部打开'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('media-action-打开链接')));
    await tester.pumpAndSettle();

    expect(fileActions.openedUrls, ['https://openai.com/research']);
    expect(find.byKey(const Key('media-actions-more-menu')), findsNothing);
    expect(find.text('复制链接'), findsNothing);
    expect(find.text('https://openai.com/research'), findsNothing);
  });

  testWidgets('link preview renders remote instant view image', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessagePreviewLinkCard(
            link: LinkCardPreview(
              url: 'https://telegra.ph/demo',
              displayUrl: 'telegra.ph/demo',
              siteName: 'Telegraph',
              title: 'Demo',
              description: '',
              remoteImageUrl: 'https://telegra.ph/file/preview.jpg',
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
  });

  testWidgets('remote image preview keeps only article content and actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: MessagePreviewLinkCard(
              link: LinkCardPreview(
                url: 'https://telegra.ph/demo',
                displayUrl: 'telegra.ph/demo',
                siteName: 'Telegraph',
                title: 'Demo Title',
                description: 'First paragraph from the article.',
                remoteImageUrl: 'https://telegra.ph/file/preview.jpg',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('link-preview-hero-image')), findsOneWidget);
    expect(find.text('Demo Title'), findsOneWidget);
    expect(find.text('First paragraph from the article.'), findsOneWidget);
    expect(find.text('Telegraph'), findsNothing);
    expect(find.text('telegra.ph/demo'), findsNothing);
    expect(find.text('外部打开'), findsOneWidget);
    expect(find.byKey(const ValueKey('media-action-打开链接')), findsOneWidget);
  });

  testWidgets(
    'link preview does not repeat the message title outside preview',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MessageViewerCard(
              message: PipelineMessage(
                id: 55,
                messageIds: [55],
                sourceChatId: 100,
                preview: MessagePreview(
                  kind: MessagePreviewKind.text,
                  title: 'Demo Title',
                  linkCard: LinkCardPreview(
                    url: 'https://telegra.ph/demo',
                    displayUrl: 'telegra.ph/demo',
                    siteName: 'Telegraph',
                    title: 'Demo Title',
                    description: 'First paragraph from the article.',
                    remoteImageUrl: 'https://telegra.ph/file/preview.jpg',
                  ),
                ),
              ),
              processing: false,
            ),
          ),
        ),
      );

      expect(find.text('Demo Title'), findsOneWidget);
      expect(find.text('First paragraph from the article.'), findsOneWidget);
    },
  );
}

class _RecordingPlatformFileActions extends PlatformFileActions {
  final List<String> openedUrls = <String>[];

  @override
  Future<void> openUrl(BuildContext context, String url) async {
    openedUrls.add(url);
  }
}
