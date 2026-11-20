import 'package:material_ui/material_ui.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_helpers.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_image_gallery.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_preview_video.dart';
import 'package:tgsorter/app/shared/presentation/widgets/telegram_media_group_layout.dart';

const _videoDurationBadgeOffset = 6.0;
const _videoDurationBadgeRadius = 4.0;
const _videoDurationBadgeHorizontalPadding = 6.0;
const _videoDurationBadgeVerticalPadding = 2.0;
const _videoDurationBadgeColor = Color(0x99000000);
const _imageFallbackText = '图片未就绪';
const _videoDurationLabelStyle = TextStyle(
  color: Colors.white,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

class MessagePreviewMedia extends StatelessWidget {
  const MessagePreviewMedia({
    super.key,
    required this.items,
    this.mediaGroup,
    required this.preparing,
    required this.onRequestPlayback,
    required this.controllerInitializer,
    this.preferVideoFallback = false,
    this.fallbackImagePath,
    this.fallbackVideoPath,
    this.fallbackThumbnailPath,
    this.isMediaPreparing,
    this.errorForMedia,
  });

  final List<MediaItemPreview> items;
  final List<MediaItemPreview>? mediaGroup;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final VideoControllerInitializer? controllerInitializer;
  final bool preferVideoFallback;
  final String? fallbackImagePath;
  final String? fallbackVideoPath;
  final String? fallbackThumbnailPath;
  final bool Function(int? messageId)? isMediaPreparing;
  final String? Function(int? messageId)? errorForMedia;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _buildFallback();
    }
    final photoItems = (mediaGroup ?? items)
        .where((item) => item.kind == MediaItemKind.photo)
        .toList(growable: false);
    if (items.length == 1) {
      return _buildSingle(items.single, photoItems);
    }
    return _buildMosaic(photoItems);
  }

  Widget _buildFallback() {
    if (preferVideoFallback ||
        fallbackVideoPath != null ||
        fallbackThumbnailPath != null) {
      return MessagePreviewVideo(
        videoPath: fallbackVideoPath,
        thumbnailPath: fallbackThumbnailPath,
        preparing: isMediaPreparing?.call(null) ?? preparing,
        onRequestPlayback: onRequestPlayback,
        controllerInitializer: controllerInitializer,
        loadErrorText: errorForMedia?.call(null),
      );
    }
    return PreviewImage(
      imagePath: fallbackImagePath,
      fallbackText: _imageFallbackText,
    );
  }

  Widget _buildSingle(
    MediaItemPreview item,
    List<MediaItemPreview> photoItems,
  ) {
    if (item.kind == MediaItemKind.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MessagePreviewVideo(
            videoPath: item.fullPath,
            videoFileId: item.fullFileId,
            thumbnailPath: item.previewPath,
            preparing: _preparing(item.messageId),
            onRequestPlayback: ([messageId]) =>
                onRequestPlayback(item.messageId),
            controllerInitializer: controllerInitializer,
            loadErrorText: errorForMedia?.call(item.messageId),
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
    final errorText = errorForMedia?.call(item.messageId);
    if (errorText != null) {
      return _PhotoStatusTile(
        item: item,
        text: errorText,
        preparing: false,
        onRetry: () => onRequestPlayback(item.messageId),
      );
    }
    return MessagePreviewImageGallery(
      items: photoItems,
      initialIndex: photoItems.indexOf(item),
      fallbackText: _imageFallbackText,
    );
  }

  Widget _buildMosaic(List<MediaItemPreview> photoItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = computeTelegramMediaGroupLayout(
          aspectRatios: items
              .map((item) => item.aspectRatio)
              .toList(growable: false),
          maxWidth: constraints.maxWidth,
          minWidth: 72,
          spacing: 8,
        );
        return SizedBox(
          height: layout.height,
          child: Stack(
            children: [
              for (var index = 0; index < items.length; index++)
                Positioned(
                  key: ValueKey(
                    'message-preview-media-tile-${items[index].messageId}',
                  ),
                  left: layout.items[index].geometry.left,
                  top: layout.items[index].geometry.top,
                  width: layout.items[index].geometry.width,
                  height: layout.items[index].geometry.height,
                  child: _buildMosaicTile(
                    context,
                    items[index],
                    layout.items[index],
                    photoItems,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMosaicTile(
    BuildContext context,
    MediaItemPreview item,
    TelegramMediaGroupLayoutItem layoutItem,
    List<MediaItemPreview> photoItems,
  ) {
    return ClipRRect(
      borderRadius: _borderRadiusFor(layoutItem),
      child: item.kind == MediaItemKind.video
          ? _VideoMosaicTile(
              item: item,
              preparing: _preparing(item.messageId),
              onRequestPlayback: onRequestPlayback,
              controllerInitializer: controllerInitializer,
              height: layoutItem.geometry.height,
              errorText: errorForMedia?.call(item.messageId),
            )
          : _buildMosaicPhoto(
              context,
              item,
              layoutItem.geometry.height,
              photoItems,
            ),
    );
  }

  Widget _buildMosaicPhoto(
    BuildContext context,
    MediaItemPreview item,
    double height,
    List<MediaItemPreview> photoItems,
  ) {
    final path = item.previewPath ?? item.fullPath;
    final preview = PreviewImage(
      imagePath: path,
      fallbackText: _imageFallbackText,
      height: height,
    );
    if (path == null || path.isEmpty) {
      return preview;
    }
    return InkWell(
      onTap: () => MessagePreviewImageGallery.show(
        context,
        items: photoItems,
        initialIndex: photoItems.indexOf(item),
      ),
      child: preview,
    );
  }

  BorderRadius _borderRadiusFor(TelegramMediaGroupLayoutItem item) {
    return BorderRadius.only(
      topLeft: item.isTop && item.isLeft
          ? const Radius.circular(18)
          : Radius.zero,
      topRight: item.isTop && item.isRight
          ? const Radius.circular(18)
          : Radius.zero,
      bottomLeft: item.isBottom && item.isLeft
          ? const Radius.circular(18)
          : Radius.zero,
      bottomRight: item.isBottom && item.isRight
          ? const Radius.circular(18)
          : Radius.zero,
    );
  }

  bool _preparing(int? messageId) {
    return isMediaPreparing?.call(messageId) ?? preparing;
  }
}

class _VideoMosaicTile extends StatelessWidget {
  const _VideoMosaicTile({
    required this.item,
    required this.preparing,
    required this.onRequestPlayback,
    required this.controllerInitializer,
    required this.height,
    required this.errorText,
  });

  final MediaItemPreview item;
  final bool preparing;
  final Future<void> Function([int? messageId]) onRequestPlayback;
  final VideoControllerInitializer? controllerInitializer;
  final double height;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MessagePreviewVideo(
          videoPath: item.fullPath,
          videoFileId: item.fullFileId,
          thumbnailPath: item.previewPath,
          preparing: preparing,
          onRequestPlayback: ([messageId]) => onRequestPlayback(item.messageId),
          controllerInitializer: controllerInitializer,
          compact: true,
          height: height,
          loadErrorText: errorText,
        ),
        if (item.durationSeconds != null)
          Positioned(
            left: _videoDurationBadgeOffset,
            bottom: _videoDurationBadgeOffset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _videoDurationBadgeColor,
                borderRadius: BorderRadius.circular(_videoDurationBadgeRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _videoDurationBadgeHorizontalPadding,
                  vertical: _videoDurationBadgeVerticalPadding,
                ),
                child: Text(
                  formatPreviewDuration(item.durationSeconds!),
                  style: _videoDurationLabelStyle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoStatusTile extends StatelessWidget {
  const _PhotoStatusTile({
    required this.item,
    required this.text,
    required this.preparing,
    required this.onRetry,
  });

  final MediaItemPreview item;
  final String text;
  final bool preparing;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preparing) const CircularProgressIndicator(),
              if (preparing) const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              if (!preparing && onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () {
                    onRetry!.call();
                  },
                  child: const Text('重试'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
