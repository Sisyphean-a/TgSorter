import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: palette.settingsSurface,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: palette.brandAccent),
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
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textMuted,
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: palette.settingsDivider),
          ],
        ),
      ),
    );
  }
}

class SettingsValueTile extends StatelessWidget {
  const SettingsValueTile({
    required this.title,
    this.value,
    this.onTap,
    super.key,
  });

  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return Material(
      color: palette.settingsSurface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title),
        subtitle: value == null ? null : Text(value!),
        trailing: Icon(Icons.chevron_right_rounded, color: palette.textMuted),
        onTap: onTap,
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return Material(
      color: palette.settingsSurface,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title),
        value: value,
        onChanged: onChanged,
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
