import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_image_gallery.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_video.dart';

class MessagePreviewMedia extends StatelessWidget {
  const MessagePreviewMedia({
    super.key,
    required this.items,
    required this.preparing,
    required this.onRequestPlayback,
    required this.controllerInitializer,
    this.preferVideoFallback = false,
    this.fallbackImagePath,
    this.fallbackVideoPath,
    this.fallbackThumbnailPath,
  });

  final List<MediaItemPreview> items;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final VideoControllerInitializer? controllerInitializer;
  final bool preferVideoFallback;
  final String? fallbackImagePath;
  final String? fallbackVideoPath;
  final String? fallbackThumbnailPath;

  @override
  Widget build(BuildContext context) {
    final photoItems = items
        .where((entry) => entry.kind == MediaItemKind.photo)
        .toList(growable: false);
    if (items.isEmpty) {
      if (preferVideoFallback ||
          fallbackVideoPath != null ||
          fallbackThumbnailPath != null) {
        return MessagePreviewVideo(
          videoPath: fallbackVideoPath,
          thumbnailPath: fallbackThumbnailPath,
          preparing: preparing,
          onRequestPlayback: onRequestPlayback,
          controllerInitializer: controllerInitializer,
        );
      }
      return PreviewImage(
        imagePath: fallbackImagePath,
        fallbackText: '图片已识别（本地文件未就绪）',
      );
    }
    if (items.length == 1) {
      return _buildItem(items.single, photoItems);
    }
    final allVideos = items.every((item) => item.kind == MediaItemKind.video);
    if (allVideos) {
      return Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _buildItem(items[index], photoItems),
            if (index < items.length - 1) const SizedBox(height: 12),
          ],
        ],
      );
    }
    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: items.length,
        controller: PageController(viewportFraction: 0.92),
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index == items.length - 1 ? 0 : 8),
            child: _buildItem(items[index], photoItems),
          );
        },
      ),
    );
  }

  Widget _buildItem(MediaItemPreview item, List<MediaItemPreview> photoItems) {
    if (item.kind == MediaItemKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewVideo(
            videoPath: item.fullPath,
            thumbnailPath: item.previewPath,
            preparing: preparing,
            onRequestPlayback: ([messageId]) =>
                onRequestPlayback(item.messageId),
            controllerInitializer: controllerInitializer,
          ),
          if (item.durationSeconds != null) ...[
            const SizedBox(height: 8),
            PreviewMetaText(
              text: '时长 ${formatPreviewDuration(item.durationSeconds!)}',
            ),
          ],
        ],
      );
    }
    final initialIndex = photoItems.indexWhere(
      (entry) => entry.messageId == item.messageId,
    );
    return MessagePreviewImageGallery(
      items: photoItems,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      fallbackText: '图片已识别（本地文件未就绪）',
    );
  }
}
