import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

enum StatusBadgeTone { accent, success, warning, danger, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(context, tone);
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

  _BadgePalette _paletteFor(BuildContext context, StatusBadgeTone value) {
    final colors = AppTokens.colorsOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return switch (value) {
      StatusBadgeTone.accent => _BadgePalette(
        background: colors.brandAccentSoft,
        foreground: colors.brandAccent,
        border: colors.borderSubtle,
      ),
      StatusBadgeTone.success => _BadgePalette(
        background: isLight
            ? colors.success.withValues(alpha: 0.14)
            : const Color(0xFF123326),
        foreground: colors.success,
        border: isLight
            ? colors.success.withValues(alpha: 0.24)
            : const Color(0xFF24543E),
      ),
      StatusBadgeTone.warning => _BadgePalette(
        background: isLight
            ? colors.warning.withValues(alpha: 0.14)
            : const Color(0xFF34270E),
        foreground: colors.warning,
        border: isLight
            ? colors.warning.withValues(alpha: 0.24)
            : const Color(0xFF5B4622),
      ),
      StatusBadgeTone.danger => _BadgePalette(
        background: isLight
            ? colors.danger.withValues(alpha: 0.12)
            : const Color(0xFF3A1B24),
        foreground: colors.danger,
        border: isLight
            ? colors.danger.withValues(alpha: 0.24)
            : const Color(0xFF5A2C38),
      ),
      StatusBadgeTone.neutral => _BadgePalette(
        background: colors.panelBackground,
        foreground: colors.textMuted,
        border: colors.borderSubtle,
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
