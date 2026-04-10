import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsGroupSection extends StatelessWidget {
  const SettingsGroupSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.highlighted = false,
    this.trailing,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool highlighted;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroupTile(
      title: title,
      subtitle: subtitle,
      highlighted: highlighted,
      trailing: trailing,
      initiallyExpanded: initiallyExpanded,
      child: child,
    );
  }
}

class _SettingsGroupTile extends StatefulWidget {
  const _SettingsGroupTile({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.highlighted,
    required this.trailing,
    required this.initiallyExpanded,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool highlighted;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  State<_SettingsGroupTile> createState() => _SettingsGroupTileState();
}

class _SettingsGroupTileState extends State<_SettingsGroupTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.panelBackground,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(
          color: widget.highlighted
              ? AppTokens.brandAccent
              : AppTokens.borderSubtle,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          maintainState: true,
          onExpansionChanged: _handleExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceLg,
            vertical: AppTokens.spaceSm,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTokens.spaceLg,
            0,
            AppTokens.spaceLg,
            AppTokens.spaceLg,
          ),
          title: _Header(
            title: widget.title,
            subtitle: widget.subtitle,
            highlighted: widget.highlighted,
            trailing: widget.trailing,
          ),
          children: [widget.child],
        ),
      ),
    );
  }

  void _handleExpansionChanged(bool expanded) {
    setState(() {
      _expanded = expanded;
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final bool highlighted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppTokens.textMuted);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(subtitle, style: subtitleStyle),
            ],
          ),
        ),
        if (highlighted) ...[
          const SizedBox(width: AppTokens.spaceSm),
          const _DirtyBadge(),
        ],
        if (trailing != null) ...[
          const SizedBox(width: AppTokens.spaceSm),
          trailing!,
        ],
      ],
    );
  }
}

class _DirtyBadge extends StatelessWidget {
  const _DirtyBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.brandAccentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTokens.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '已修改',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppTokens.brandAccent),
        ),
      ),
    );
  }
}
