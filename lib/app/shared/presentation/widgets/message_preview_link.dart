import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/platform_file_actions.dart';

class MessagePreviewLinkCard extends StatefulWidget {
  const MessagePreviewLinkCard({
    super.key,
    required this.link,
    this.fileActions = const PlatformFileActions(),
  });

  final LinkCardPreview link;
  final PlatformFileActions fileActions;

  @override
  State<MessagePreviewLinkCard> createState() => _MessagePreviewLinkCardState();
}

class _MessagePreviewLinkCardState extends State<MessagePreviewLinkCard> {
  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final image = _buildHeroImage(link);
    final headline = _headlineFor(link);
    final summary = _summaryFor(link, headline);
    return KeyedSubtree(
      key: const Key('message-preview-link-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?image,
          Padding(
            padding: EdgeInsets.only(top: image == null ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LinkPreviewText(headline: headline, summary: summary),
                ),
                const SizedBox(width: 8),
                _LinkPreviewActions(
                  link: link,
                  fileActions: widget.fileActions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildHeroImage(LinkCardPreview link) {
    final localPath = link.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      return _heroFrame(
        Image.file(
          io.File(localPath),
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
        ),
      );
    }
    final remoteUrl = link.remoteImageUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      return null;
    }
    return _heroFrame(
      Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _heroFrame(Widget image) {
    return ClipRRect(
      key: const Key('link-preview-hero-image'),
      borderRadius: BorderRadius.circular(6),
      child: AspectRatio(aspectRatio: 16 / 10, child: image),
    );
  }

  String _headlineFor(LinkCardPreview link) {
    final title = link.title.trim();
    if (title.isNotEmpty) {
      return title;
    }
    final description = link.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    return link.displayUrl.trim().isEmpty ? link.url : link.displayUrl;
  }

  String? _summaryFor(LinkCardPreview link, String headline) {
    final description = link.description.trim();
    if (description.isEmpty || description == headline) {
      return null;
    }
    return description;
  }
}

class _LinkPreviewText extends StatelessWidget {
  const _LinkPreviewText({required this.headline, required this.summary});

  final String headline;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        if (summary != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              summary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _LinkPreviewActions extends StatelessWidget {
  const _LinkPreviewActions({required this.link, required this.fileActions});

  final LinkCardPreview link;
  final PlatformFileActions fileActions;

  @override
  Widget build(BuildContext context) {
    if (!fileActions.canOpenUrl(link.url)) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      key: const ValueKey('media-action-打开链接'),
      onPressed: () => fileActions.openUrl(context, link.url),
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: const Text('外部打开'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
