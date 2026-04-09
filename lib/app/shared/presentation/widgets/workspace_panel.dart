import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    this.title,
    required this.child,
    this.subtitle,
  });

  final String? title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeader =
        (title?.isNotEmpty ?? false) || (subtitle?.isNotEmpty ?? false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
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
                    color: AppTokens.textMuted,
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
