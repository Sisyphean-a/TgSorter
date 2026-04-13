import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';

class SettingsHomePage extends StatelessWidget {
  const SettingsHomePage({required this.onOpenRoute, super.key});

  final ValueChanged<SettingsRoute> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
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
        _SettingsHomeTile(
          route: SettingsRoute.connection,
          icon: Icons.wifi_tethering_rounded,
          onTap: onOpenRoute,
        ),
        _SettingsHomeTile(
          route: SettingsRoute.appearance,
          icon: Icons.palette_outlined,
          onTap: onOpenRoute,
        ),
        _SettingsHomeTile(
          route: SettingsRoute.shortcuts,
          icon: Icons.keyboard_command_key_rounded,
          onTap: onOpenRoute,
        ),
      ],
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
    return ListTile(
      key: ValueKey('settings-home-${route.name}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon),
      title: Text(route.title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => onTap(route),
    );
  }
}
