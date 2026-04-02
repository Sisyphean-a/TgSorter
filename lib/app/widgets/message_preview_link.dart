import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:tgsorter/app/domain/message_preview_mapper.dart';
import 'package:url_launcher/url_launcher.dart';

class MessagePreviewLinkCard extends StatelessWidget {
  const MessagePreviewLinkCard({super.key, required this.link});

  final LinkCardPreview link;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        link.localImagePath != null && link.localImagePath!.isNotEmpty;
    return Card(
      key: const Key('message-preview-link-card'),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          final uri = Uri.tryParse(link.url);
          if (uri == null) {
            return;
          }
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
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
                    errorBuilder: (_, _, _) => const SizedBox(width: 72),
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    );
  }
}
