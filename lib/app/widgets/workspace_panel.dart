import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
