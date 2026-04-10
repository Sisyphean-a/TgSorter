import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_link.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

void main() {
  testWidgets('link preview exposes actions and expandable details', (
    tester,
  ) async {
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

    await tester.tap(find.byKey(const ValueKey('media-action-打开链接')));
    await tester.pumpAndSettle();

    expect(fileActions.openedUrls, ['https://openai.com/research']);

    await tester.tap(find.byKey(const Key('media-actions-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制链接').last);
    await tester.pumpAndSettle();

    expect(fileActions.copiedTexts, ['https://openai.com/research']);
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
}

class _RecordingPlatformFileActions extends PlatformFileActions {
  final List<String> openedUrls = <String>[];
  final List<String> copiedTexts = <String>[];

  @override
  Future<void> openUrl(BuildContext context, String url) async {
    openedUrls.add(url);
  }

  @override
  Future<void> copyText(
    BuildContext context,
    String text, {
    String successMessage = '内容已复制',
  }) async {
    copiedTexts.add(text);
  }
}
