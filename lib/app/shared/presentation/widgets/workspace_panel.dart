import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    this.title,
    required this.child,
    this.subtitle,
    this.dense = false,
  });

  final String? title;
  final String? subtitle;
  final Widget child;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    final hasHeader =
        (title?.isNotEmpty ?? false) || (subtitle?.isNotEmpty ?? false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(
          dense ? AppTokens.radiusMedium : AppTokens.radiusLarge,
        ),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? AppTokens.spaceMd : AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader) ...[
              if (title case final text?) ...[
                Text(
                  text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (subtitle case final text?) ...[
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.spaceMd),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
