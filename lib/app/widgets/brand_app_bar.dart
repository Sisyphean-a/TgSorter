import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTokens.spaceLg,
            AppTokens.spaceMd,
            AppTokens.spaceLg,
            AppTokens.spaceSm,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.panelBackground,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
              border: Border.all(color: AppTokens.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceLg,
                vertical: AppTokens.spaceMd,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Headline(title: title, subtitle: subtitle),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle case final text?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTokens.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
