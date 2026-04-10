import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_actions.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_shell.dart';
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
    final image = _buildPreviewImage(link);
    return KeyedSubtree(
      key: const Key('message-preview-link-card'),
      child: MessageMediaShell(
        actions: _buildPrimaryActions(link),
        moreActions: _buildMoreActions(link),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: InkWell(
            onTap: widget.fileActions.canOpenUrl(link.url)
                ? () => widget.fileActions.openUrl(context, link.url)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: image,
                    ),
                  if (image != null) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (link.siteName.isNotEmpty)
                          Text(
                            link.siteName,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        if (link.title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              link.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (link.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              link.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          link.displayUrl.isEmpty ? link.url : link.displayUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildPreviewImage(LinkCardPreview link) {
    final localPath = link.localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        io.File(localPath),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => const SizedBox(width: 72),
      );
    }
    final remoteUrl = link.remoteImageUrl;
    if (remoteUrl == null || remoteUrl.isEmpty) {
      return null;
    }
    return Image.network(
      remoteUrl,
      width: 72,
      height: 72,
      fit: BoxFit.cover,
      errorBuilder: (_, error, stackTrace) => const SizedBox(width: 72),
    );
  }

  List<MessageMediaAction> _buildPrimaryActions(LinkCardPreview link) {
    return [
      if (widget.fileActions.canOpenUrl(link.url))
        MessageMediaAction(
          icon: Icons.open_in_new_rounded,
          label: '打开链接',
          onPressed: (context) => widget.fileActions.openUrl(context, link.url),
        ),
    ];
  }

  List<MessageMediaAction> _buildMoreActions(LinkCardPreview link) {
    return [
      MessageMediaAction(
        icon: Icons.copy_rounded,
        label: '复制链接',
        onPressed: (context) => widget.fileActions.copyText(
          context,
          link.url,
          successMessage: '链接已复制',
        ),
      ),
    ];
  }
}
