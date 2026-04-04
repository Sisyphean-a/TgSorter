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
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final link = widget.link;
    final hasImage =
        link.localImagePath != null && link.localImagePath!.isNotEmpty;
    return KeyedSubtree(
      key: const Key('message-preview-link-card'),
      child: MessageMediaShell(
        header: _LinkHeader(link: link),
        actions: _buildPrimaryActions(link),
        moreActions: _buildMoreActions(link),
        footer: _LinkFooter(
          expanded: _expanded,
          link: link,
          onToggleExpanded: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
        ),
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
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        io.File(link.localImagePath!),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) =>
                            const SizedBox(width: 72),
                      ),
                    ),
                  if (hasImage) const SizedBox(width: 12),
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
                              maxLines: _expanded ? null : 3,
                              overflow: _expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
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

class _LinkHeader extends StatelessWidget {
  const _LinkHeader({required this.link});

  final LinkCardPreview link;

  @override
  Widget build(BuildContext context) {
    final site = link.siteName.isEmpty ? '网页卡片' : link.siteName;
    final subtitle = link.title.isEmpty ? link.displayUrl : link.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(site),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
        ],
      ],
    );
  }
}

class _LinkFooter extends StatelessWidget {
  const _LinkFooter({
    required this.expanded,
    required this.link,
    required this.onToggleExpanded,
  });

  final bool expanded;
  final LinkCardPreview link;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggleExpanded,
            icon: Icon(
              expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            label: Text(expanded ? '收起详情' : '展开详情'),
          ),
        ),
        if (expanded) ...[
          _LinkDetailLine(label: '完整链接', value: link.url),
          if (link.displayUrl.isNotEmpty)
            _LinkDetailLine(label: '展示链接', value: link.displayUrl),
          if (link.siteName.isNotEmpty)
            _LinkDetailLine(label: '站点', value: link.siteName),
          if (link.title.isNotEmpty)
            _LinkDetailLine(label: '标题', value: link.title),
          if (link.description.isNotEmpty)
            _LinkDetailLine(label: '描述', value: link.description),
        ],
      ],
    );
  }
}

class _LinkDetailLine extends StatelessWidget {
  const _LinkDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}
