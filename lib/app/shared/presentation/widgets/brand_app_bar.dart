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
  Size get preferredSize => const Size.fromHeight(148);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Material(
      color: AppTokens.pageBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? AppTokens.spaceMd : AppTokens.spaceLg,
            AppTokens.spaceMd,
            compact ? AppTokens.spaceMd : AppTokens.spaceLg,
            AppTokens.spaceSm,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTokens.panelBackground,
              borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
              border: Border.all(color: AppTokens.borderSubtle),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? AppTokens.spaceMd : AppTokens.spaceLg,
                vertical: AppTokens.spaceMd,
              ),
              child: compact
                  ? _CompactHeader(
                      title: title,
                      subtitle: null,
                      badges: badges,
                      actions: actions,
                    )
                  : _WideHeader(
                      title: title,
                      subtitle: subtitle,
                      badges: badges,
                      actions: actions,
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
  });

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final List<Widget> badges;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Headline(title: title, subtitle: subtitle, compact: true),
            ),
            if (actions.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: actions),
          ],
        ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: AppTokens.spaceSm),
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
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
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
                color: AppTokens.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}
