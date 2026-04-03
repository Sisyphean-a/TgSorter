import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

enum StatusBadgeTone { accent, success, warning, danger, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tone);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: palette.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  _BadgePalette _paletteFor(StatusBadgeTone value) {
    return switch (value) {
      StatusBadgeTone.accent => const _BadgePalette(
        background: AppTokens.brandAccentSoft,
        foreground: AppTokens.brandAccent,
        border: AppTokens.borderSubtle,
      ),
      StatusBadgeTone.success => const _BadgePalette(
        background: Color(0xFF123326),
        foreground: AppTokens.success,
        border: Color(0xFF24543E),
      ),
      StatusBadgeTone.warning => const _BadgePalette(
        background: Color(0xFF34270E),
        foreground: AppTokens.warning,
        border: Color(0xFF5B4622),
      ),
      StatusBadgeTone.danger => const _BadgePalette(
        background: Color(0xFF3A1B24),
        foreground: AppTokens.danger,
        border: Color(0xFF5A2C38),
      ),
      StatusBadgeTone.neutral => const _BadgePalette(
        background: AppTokens.panelBackground,
        foreground: AppTokens.textMuted,
        border: AppTokens.borderSubtle,
      ),
    };
  }
}

class _BadgePalette {
  const _BadgePalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}
