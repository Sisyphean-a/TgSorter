import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.actions = const [],
    this.height = defaultHeight,
  });

  static const double defaultHeight = 148;
  static const double compactHeight = 96;

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final colors = AppTokens.colorsOf(context);
    final dense = height <= compactHeight;
    return Material(
      color: colors.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? AppTokens.spaceMd : AppTokens.spaceLg,
            dense ? AppTokens.spaceXs : AppTokens.spaceMd,
            compact ? AppTokens.spaceMd : AppTokens.spaceLg,
            dense ? AppTokens.spaceXs : AppTokens.spaceSm,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.panelBackground,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppTokens.spaceMd : AppTokens.spaceLg,
                vertical: dense ? AppTokens.spaceXs : AppTokens.spaceMd,
              ),
              child: compact
                  ? _CompactHeader(
                      title: title,
                      subtitle: null,
                      badges: badges,
                      actions: actions,
                      dense: dense,
                    )
                  : _WideHeader(
                      title: title,
                      subtitle: subtitle,
                      badges: badges,
                      actions: actions,
                      dense: dense,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WideHeader extends StatelessWidget {
  const _WideHeader({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.actions,
    required this.dense,
  });

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Headline(title: title, subtitle: subtitle, dense: dense),
        ),
        if (badges.isNotEmpty) ...[
          Wrap(
            spacing: AppTokens.spaceXs,
            runSpacing: AppTokens.spaceXs,
            alignment: WrapAlignment.end,
            children: badges,
          ),
          const SizedBox(width: AppTokens.spaceSm),
        ],
        ...actions,
      ],
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.actions,
    required this.dense,
  });

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Headline(
                title: title,
                subtitle: subtitle,
                compact: true,
                dense: dense,
              ),
            ),
            if (actions.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
        if (badges.isNotEmpty) ...[
          SizedBox(height: dense ? AppTokens.spaceXs : AppTokens.spaceSm),
          Wrap(
            spacing: AppTokens.spaceXs,
            runSpacing: AppTokens.spaceXs,
            children: badges,
          ),
        ],
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppTokens.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (dense
                      ? theme.textTheme.titleMedium
                      : compact
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle case final text?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
