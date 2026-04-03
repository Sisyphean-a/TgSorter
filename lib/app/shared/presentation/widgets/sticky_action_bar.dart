import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class StickyActionBar extends StatelessWidget {
  const StickyActionBar({
    super.key,
    required this.isDirty,
    required this.onDiscard,
    required this.onSave,
  });

  final bool isDirty;
  final Future<void> Function() onDiscard;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDirty
                ? AppTokens.surfaceRaised
                : AppTokens.panelBackground,
            borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
            border: Border.all(
              color: isDirty ? AppTokens.brandAccent : AppTokens.borderSubtle,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isDirty ? '当前有未保存更改' : '设置已同步',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      isDirty ? '等待保存' : '已保存',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDirty
                            ? AppTokens.brandAccent
                            : AppTokens.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDirty ? onDiscard : null,
                        child: const Text('放弃更改'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isDirty ? onSave : null,
                        child: const Text('保存更改'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
