import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsDetailPage extends StatelessWidget {
  const SettingsDetailPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return ColoredBox(
      color: palette.settingsBackground,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [child],
      ),
    );
  }
}
