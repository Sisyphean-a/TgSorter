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
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
                    color: isDirty ? AppTokens.brandAccent : AppTokens.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isDirty ? onDiscard : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('放弃更改'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isDirty ? onSave : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('保存更改'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
