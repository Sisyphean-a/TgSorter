import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/category_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

const _trayRadius = 8.0;
const _trayPadding = 10.0;
const _categorySpacing = 8.0;
const _categoryColumnsBreakpoint = 360.0;
const _wideCategoryColumns = 3;
const _narrowCategoryColumns = 2;
const _categoryButtonHeight = 36.0;
const _categoryButtonHorizontalPadding = 8.0;
const _categoryButtonVerticalPadding = 6.0;
const _statusGap = 6.0;

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
    final colors = AppTokens.colorsOf(context);
    return AnimatedContainer(
      duration: AppTokens.quick,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: colors.panelBackground,
        borderRadius: BorderRadius.circular(_trayRadius),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_trayPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._statusWidgets(context, colors),
            _categoryContent(context, colors),
            const SizedBox(height: _statusGap),
            secondaryActions,
          ],
        ),
      ),
    );
  }

  List<Widget> _statusWidgets(BuildContext context, AppColorPalette colors) {
    if (online) {
      return const [];
    }
    return [
      Text(
        '离线，分类已禁用',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.danger),
      ),
      const SizedBox(height: _statusGap),
    ];
  }

  Widget _categoryContent(BuildContext context, AppColorPalette colors) {
    if (categories.isEmpty) {
      return Text(
        '暂无分类',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return _categoryGrid(
          context: context,
          colors: colors,
          maxWidth: constraints.maxWidth,
        );
      },
    );
  }

  Widget _categoryGrid({
    required BuildContext context,
    required AppColorPalette colors,
    required double maxWidth,
  }) {
    final columns = maxWidth >= _categoryColumnsBreakpoint
        ? _wideCategoryColumns
        : _narrowCategoryColumns;
    final itemWidth = (maxWidth - _categorySpacing * (columns - 1)) / columns;
    return Wrap(
      spacing: _categorySpacing,
      runSpacing: _categorySpacing,
      children: [
        for (final category in categories)
          _categoryButton(
            context: context,
            colors: colors,
            category: category,
            width: itemWidth,
          ),
      ],
    );
  }

  Widget _categoryButton({
    required BuildContext context,
    required AppColorPalette colors,
    required CategoryConfig category,
    required double width,
  }) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: FilledButton(
        onPressed: canClick ? () => onClassify(category.key) : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(_categoryButtonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: _categoryButtonHorizontalPadding,
            vertical: _categoryButtonVerticalPadding,
          ),
          backgroundColor: colors.brandAccent,
          foregroundColor: theme.colorScheme.onPrimary,
          disabledBackgroundColor: colors.surfaceRaised,
          disabledForegroundColor: colors.textMuted,
          textStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_trayRadius),
          ),
        ),
        child: Text(
          category.targetChatTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
