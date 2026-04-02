import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class MobileActionTray extends StatelessWidget {
  const MobileActionTray({
    super.key,
    required this.categories,
    required this.canClick,
    required this.online,
    required this.onClassify,
    required this.secondaryActions,
  });

  final List<CategoryConfig> categories;
  final bool canClick;
  final bool online;
  final ValueChanged<String> onClassify;
  final Widget secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: AppTokens.quick,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: AppTokens.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!online) ...[
              Text(
                '当前网络不可用，分类按钮已禁用',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTokens.danger,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (categories.isEmpty)
              Text(
                '暂无分类，请先到设置页新增',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTokens.textMuted,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0;
                  final columns = constraints.maxWidth >= 360 ? 3 : 2;
                  final itemWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final category in categories)
                        SizedBox(
                          width: itemWidth,
                          child: FilledButton(
                            onPressed: canClick
                                ? () => onClassify(category.key)
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              backgroundColor: AppTokens.brandAccent,
                              foregroundColor: const Color(0xFF03211C),
                              disabledBackgroundColor: AppTokens.surfaceRaised,
                              disabledForegroundColor: AppTokens.textMuted,
                              textStyle: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusSmall,
                                ),
                              ),
                            ),
                            child: Text(
                              category.targetChatTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 6),
            secondaryActions,
          ],
        ),
      ),
    );
  }
}
