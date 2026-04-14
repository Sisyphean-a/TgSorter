import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: palette.settingsSurface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: palette.settingsIcon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Text(
                  value!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: palette.settingsValue,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsValueTile extends StatelessWidget {
  const SettingsValueTile({
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.danger = false,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    final titleColor = danger ? palette.danger : palette.textPrimary;
    final valueColor = danger ? palette.danger : palette.settingsValue;
    return Material(
      color: palette.settingsSurface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 2,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return Material(
      color: palette.settingsSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              activeThumbColor: Colors.white,
              activeTrackColor: palette.settingsValue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: palette.textMuted.withAlpha(110),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: palette.brandAccent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SettingsSectionBlock extends StatelessWidget {
  const SettingsSectionBlock({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    final rounded = MediaQuery.sizeOf(context).width >= 960;
    return Material(
      color: palette.settingsSurface,
      borderRadius: rounded ? BorderRadius.circular(16) : null,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: palette.settingsDivider,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
