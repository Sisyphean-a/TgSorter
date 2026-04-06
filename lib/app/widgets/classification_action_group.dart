import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

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
    if (categories.isEmpty) {
      return Text(
        '暂无分类',
        style: theme.textTheme.bodyMedium?.copyWith(color: AppTokens.textMuted),
      );
    }

    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (final category in categories)
          AnimatedContainer(
            duration: AppTokens.quick,
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              boxShadow: enabled
                  ? const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ]
                  : const [],
            ),
            child: FilledButton.tonal(
              onPressed: enabled ? () => onClassify(category.key) : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(180, 52),
                backgroundColor: AppTokens.surfaceRaised,
                foregroundColor: AppTokens.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  side: const BorderSide(color: AppTokens.borderSubtle),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(category.targetChatTitle),
            ),
          ),
      ],
    );
  }
}
