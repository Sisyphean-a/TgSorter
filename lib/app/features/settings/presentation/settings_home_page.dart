import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({required this.onOpenRoute, super.key});

  final ValueChanged<SettingsRoute> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return ColoredBox(
      color: palette.settingsBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
        children: [
          const SettingsSectionHeader(title: '工作流'),
          _SettingsHomeTile(
            route: SettingsRoute.forwarding,
            icon: Icons.forward_to_inbox_rounded,
            onTap: onOpenRoute,
          ),
          _SettingsHomeTile(
            route: SettingsRoute.tagging,
            icon: Icons.sell_rounded,
            onTap: onOpenRoute,
          ),
          const SizedBox(height: 12),
          const SettingsSectionHeader(title: '应用'),
          _SettingsHomeTile(
            route: SettingsRoute.common,
            icon: Icons.tune_rounded,
            onTap: onOpenRoute,
          ),
          _SettingsHomeTile(
            route: SettingsRoute.downloads,
            icon: Icons.download_for_offline_rounded,
            onTap: onOpenRoute,
          ),
          _SettingsHomeTile(
            route: SettingsRoute.skippedMessages,
            icon: Icons.settings_backup_restore_rounded,
            onTap: onOpenRoute,
          ),
          _SettingsHomeTile(
            route: SettingsRoute.connection,
            icon: Icons.wifi_tethering_rounded,
            onTap: onOpenRoute,
          ),
          _SettingsHomeTile(
            route: SettingsRoute.shortcuts,
            icon: Icons.keyboard_command_key_rounded,
            onTap: onOpenRoute,
          ),
          const SizedBox(height: 12),
          const SettingsSectionHeader(title: '账号'),
          _SettingsHomeTile(
            route: SettingsRoute.accountSession,
            icon: Icons.shield_moon_outlined,
            onTap: onOpenRoute,
          ),
        ],
      ),
    );
  }
}

class _SettingsHomeTile extends StatelessWidget {
  const _SettingsHomeTile({
    required this.route,
    required this.icon,
    required this.onTap,
  });

  final SettingsRoute route;
  final IconData icon;
  final ValueChanged<SettingsRoute> onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsNavigationTile(
      key: ValueKey('settings-home-${route.name}'),
      icon: icon,
      title: route.homeLabel,
      onTap: () => onTap(route),
    );
  }
}
