import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class TagActionGroup extends StatelessWidget {
  const TagActionGroup({
    super.key,
    required this.tags,
    required this.enabled,
    required this.onTagSelected,
  });

  final List<TagConfig> tags;
  final bool enabled;
  final ValueChanged<String> onTagSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    if (tags.isEmpty) {
      return Text(
        '暂无标签',
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
      );
    }
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (final tag in tags)
          FilledButton(
            onPressed: enabled ? () => onTagSelected(tag.name) : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(112, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: colors.brandAccent,
              foregroundColor: theme.colorScheme.onPrimary,
              disabledBackgroundColor: colors.surfaceRaised,
              disabledForegroundColor: colors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              tag.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}
