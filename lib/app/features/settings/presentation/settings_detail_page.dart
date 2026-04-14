import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_surface.dart';

class SettingsDetailPage extends StatelessWidget {
  const SettingsDetailPage({
    required this.child,
    this.ignoring = false,
    super.key,
  });

  final Widget child;
  final bool ignoring;

  @override
  Widget build(BuildContext context) {
    return SettingsScrollableSurface(
      ignoring: ignoring,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: child,
    );
  }
}
