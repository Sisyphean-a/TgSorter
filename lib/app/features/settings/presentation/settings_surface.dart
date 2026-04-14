import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsScrollableSurface extends StatelessWidget {
  const SettingsScrollableSurface({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(0, 16, 0, 24),
    this.ignoring = false,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool ignoring;

  @override
  Widget build(BuildContext context) {
    final palette = AppTokens.colorsOf(context);
    return ColoredBox(
      color: palette.settingsBackground,
      child: IgnorePointer(
        ignoring: ignoring,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;
            final content = Padding(
              padding: padding,
              child: child,
            );
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                if (isDesktop)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      key: const ValueKey('settings-desktop-column'),
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: content,
                    ),
                  )
                else
                  content,
              ],
            );
          },
        ),
      ),
    );
  }
}
