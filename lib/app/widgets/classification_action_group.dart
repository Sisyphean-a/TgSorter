import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

const _buttonRadius = 8.0;
const _actionButtonWidth = 160.0;
const _actionButtonHeight = 44.0;

class ClassificationActionGroup extends StatelessWidget {
  const ClassificationActionGroup({
    super.key,
    required this.categories,
    required this.enabled,
    required this.onClassify,
  });

  final List<CategoryConfig> categories;
  final bool enabled;
  final ValueChanged<String> onClassify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    if (categories.isEmpty) {
      return Text(
        '暂无分类',
        style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
      );
    }

    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (final entry in categories.indexed)
          AnimatedContainer(
            duration: AppTokens.quick,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_buttonRadius),
            ),
            child: FilledButton(
              onPressed: enabled ? () => onClassify(entry.$2.key) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  _actionButtonWidth,
                  _actionButtonHeight,
                ),
                backgroundColor: colors.brandAccent,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor: colors.surfaceRaised,
                disabledForegroundColor: colors.textMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_buttonRadius),
                  side: BorderSide(color: colors.borderSubtle),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(
                '${entry.$1 + 1} ${entry.$2.targetChatTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }
}
