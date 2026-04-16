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
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: padding,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
