import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_image_gallery.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

void main() {
  testWidgets('image gallery shows unified shell for multi-image content', (
    tester,
  ) async {
    final fileActions = _RecordingPlatformFileActions();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagePreviewImageGallery(
            items: const [
              MediaItemPreview(
                messageId: 1,
                kind: MediaItemKind.photo,
                previewPath: 'C:/demo/a.jpg',
                fullPath: 'C:/demo/a.jpg',
              ),
              MediaItemPreview(
                messageId: 2,
                kind: MediaItemKind.photo,
                previewPath: 'C:/demo/b.jpg',
                fullPath: 'C:/demo/b.jpg',
              ),
            ],
            initialIndex: 0,
            fallbackText: '图片未就绪',
            fileActions: fileActions,
          ),
        ),
      ),
    );

    expect(find.text('图片预览'), findsOneWidget);
    expect(find.text('支持大图查看、切换和文件动作'), findsNothing);
    expect(find.text('共 2 张，点击进入画廊查看'), findsNothing);
    expect(find.byKey(const ValueKey('media-action-查看大图')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-actions-more-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('复制路径').last);
    await tester.pumpAndSettle();

    expect(fileActions.copiedPaths, ['C:/demo/a.jpg']);
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
