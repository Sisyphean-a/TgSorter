import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

const double _settingsTileHorizontalPadding = 16;
const double _settingsTileValueGap = 12;
const double _settingsTileIndicatorGap = 8;
const double _settingsTileChevronWidth = 24;
const double _settingsTileSwitchWidth = 56;
const double _settingsTileValueWidthFactor = 0.42;
const double _settingsTileValueMaxWidth = 220;

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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _settingsTileHorizontalPadding, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.brandAccentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(icon, color: palette.brandAccent, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w500,
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
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted, size: 20),
          ],
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _settingsTileHorizontalPadding,
          vertical: 14,
        ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final indicatorWidth = trailing != null
                  ? _settingsTileSwitchWidth
                  : onTap != null
                  ? _settingsTileChevronWidth
                  : 0.0;
              final valueWidth = value == null
                  ? 0.0
                  : _resolveValueWidth(
                      maxWidth: constraints.maxWidth,
                      indicatorWidth: indicatorWidth,
                    );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _SettingsTileTextBlock(
                      title: title,
                      subtitle: subtitle,
                      titleColor: titleColor,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: _settingsTileValueGap),
                    SizedBox(
                      width: valueWidth,
                      child: Text(
                        value!,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: valueColor,
                        ),
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: _settingsTileValueGap),
                    SizedBox(
                      width: _settingsTileSwitchWidth,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing!,
                      ),
                    ),
                  ] else if (onTap != null) ...[
                    const SizedBox(width: _settingsTileIndicatorGap),
                    const _SettingsTileChevron(),
                  ],
                ],
              );
            },
          ),
        ),
    );
  }

  double _resolveValueWidth({
    required double maxWidth,
    required double indicatorWidth,
  }) {
    final available = maxWidth - indicatorWidth - _settingsTileValueGap;
    final proportional = available * _settingsTileValueWidthFactor;
    return proportional.clamp(96.0, _settingsTileValueMaxWidth);
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
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _settingsTileHorizontalPadding,
          vertical: 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _SettingsTileTextBlock(
                title: title,
                subtitle: subtitle,
                titleColor: palette.textPrimary,
              ),
            ),
            const SizedBox(width: _settingsTileValueGap),
            SizedBox(
              width: _settingsTileSwitchWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: Switch(
                  value: value,
                  activeThumbColor: Colors.white,
                  activeTrackColor: palette.settingsValue,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: palette.textMuted.withAlpha(110),
                  onChanged: onChanged,
                ),
              ),
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
      padding: const EdgeInsets.fromLTRB(36, 24, 36, 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: palette.brandAccent,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.settingsSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(16),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: _settingsTileHorizontalPadding),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: palette.settingsDivider.withAlpha(120),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsTileTextBlock extends StatelessWidget {
  const _SettingsTileTextBlock({
    required this.title,
    required this.subtitle,
    required this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(color: titleColor),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

class _SettingsTileChevron extends StatelessWidget {
  const _SettingsTileChevron();

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return SizedBox(
      width: _settingsTileChevronWidth,
      child: Icon(
        Icons.chevron_right_rounded,
        color: palette.textMuted,
      ),
    );
  }
}
