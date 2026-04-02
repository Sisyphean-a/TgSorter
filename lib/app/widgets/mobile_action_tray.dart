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
        color: online ? AppTokens.panelBackground : AppTokens.surfaceBase,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(
          color: online ? AppTokens.borderSubtle : AppTokens.danger,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '分类操作',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                online ? '操作区固定在底部，便于连续分类' : '当前网络不可用，分类按钮已禁用',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: online ? AppTokens.textMuted : AppTokens.danger,
                ),
              ),
              const SizedBox(height: AppTokens.spaceMd),
              if (categories.isEmpty)
                Text(
                  '暂无分类，请先到设置页新增',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTokens.textMuted,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < categories.length; index++) ...[
                      FilledButton(
                        onPressed: canClick
                            ? () => onClassify(categories[index].key)
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: AppTokens.brandAccent,
                          foregroundColor: const Color(0xFF03211C),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusSmall,
                            ),
                          ),
                        ),
                        child: Text(categories[index].targetChatTitle),
                      ),
                      if (index < categories.length - 1)
                        const SizedBox(height: AppTokens.spaceSm),
                    ],
                  ],
                ),
              const SizedBox(height: AppTokens.spaceMd),
              secondaryActions,
            ],
          ),
        ),
      ),
    );
  }
}
