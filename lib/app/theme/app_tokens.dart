import 'package:flutter/material.dart';

@immutable
class AppColorPalette extends ThemeExtension<AppColorPalette> {
  const AppColorPalette({
    required this.pageBackground,
    required this.panelBackground,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.borderSubtle,
    required this.brandAccent,
    required this.brandAccentSoft,
    required this.textPrimary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.settingsAppBar,
    required this.settingsBackground,
    required this.settingsSurface,
    required this.settingsDivider,
    required this.settingsIcon,
    required this.settingsValue,
  });

  final Color pageBackground;
  final Color panelBackground;
  final Color surfaceBase;
  final Color surfaceRaised;
  final Color borderSubtle;
  final Color brandAccent;
  final Color brandAccentSoft;
  final Color textPrimary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color settingsAppBar;
  final Color settingsBackground;
  final Color settingsSurface;
  final Color settingsDivider;
  final Color settingsIcon;
  final Color settingsValue;

  @override
  AppColorPalette copyWith({
    Color? pageBackground,
    Color? panelBackground,
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? borderSubtle,
    Color? brandAccent,
    Color? brandAccentSoft,
    Color? textPrimary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? settingsAppBar,
    Color? settingsBackground,
    Color? settingsSurface,
    Color? settingsDivider,
    Color? settingsIcon,
    Color? settingsValue,
  }) {
    return AppColorPalette(
      pageBackground: pageBackground ?? this.pageBackground,
      panelBackground: panelBackground ?? this.panelBackground,
      surfaceBase: surfaceBase ?? this.surfaceBase,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      brandAccent: brandAccent ?? this.brandAccent,
      brandAccentSoft: brandAccentSoft ?? this.brandAccentSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      settingsAppBar: settingsAppBar ?? this.settingsAppBar,
      settingsBackground: settingsBackground ?? this.settingsBackground,
      settingsSurface: settingsSurface ?? this.settingsSurface,
      settingsDivider: settingsDivider ?? this.settingsDivider,
      settingsIcon: settingsIcon ?? this.settingsIcon,
      settingsValue: settingsValue ?? this.settingsValue,
    );
  }

  @override
  AppColorPalette lerp(ThemeExtension<AppColorPalette>? other, double t) {
    if (other is! AppColorPalette) {
      return this;
    }
    return AppColorPalette(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      panelBackground: Color.lerp(panelBackground, other.panelBackground, t)!,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      brandAccentSoft: Color.lerp(
        brandAccentSoft,
        other.brandAccentSoft,
        t,
      )!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      settingsAppBar: Color.lerp(settingsAppBar, other.settingsAppBar, t)!,
      settingsBackground: Color.lerp(
        settingsBackground,
        other.settingsBackground,
        t,
      )!,
      settingsSurface: Color.lerp(settingsSurface, other.settingsSurface, t)!,
      settingsDivider: Color.lerp(settingsDivider, other.settingsDivider, t)!,
      settingsIcon: Color.lerp(settingsIcon, other.settingsIcon, t)!,
      settingsValue: Color.lerp(settingsValue, other.settingsValue, t)!,
    );
  }
}

abstract final class AppTokens {
  static const AppColorPalette lightPalette = AppColorPalette(
    pageBackground: Color(0xFFF4F5F7),
    panelBackground: Color(0xFFFFFFFF),
    surfaceBase: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF8FAFC),
    borderSubtle: Color(0xFFD9E1E8),
    brandAccent: Color(0xFF3390EC),
    brandAccentSoft: Color(0xFFE9F3FF),
    textPrimary: Color(0xFF1F2329),
    textMuted: Color(0xFF74808B),
    success: Color(0xFF2CB67D),
    warning: Color(0xFFE3A008),
    danger: Color(0xFFE24D4D),
    settingsAppBar: Color(0xFF3390EC),
    settingsBackground: Color(0xFFF1F5F9),
    settingsSurface: Color(0xFFFFFFFF),
    settingsDivider: Color(0xFFD9E1E8),
    settingsIcon: Color(0xFF8F99A3),
    settingsValue: Color(0xFF3390EC),
  );

  static const AppColorPalette darkPalette = AppColorPalette(
    pageBackground: Color(0xFF17191C),
    panelBackground: Color(0xFF23262A),
    surfaceBase: Color(0xFF23262A),
    surfaceRaised: Color(0xFF2D3136),
    borderSubtle: Color(0xFF3B4148),
    brandAccent: Color(0xFF5CA8F5),
    brandAccentSoft: Color(0xFF163A5C),
    textPrimary: Color(0xFFF5F7FA),
    textMuted: Color(0xFFADB6C2),
    success: Color(0xFF4DD39C),
    warning: Color(0xFFF4BC42),
    danger: Color(0xFFFF8A80),
    settingsAppBar: Color(0xFF5CA8F5),
    settingsBackground: Color(0xFF17191C),
    settingsSurface: Color(0xFF23262A),
    settingsDivider: Color(0xFF3B4148),
    settingsIcon: Color(0xFFADB6C2),
    settingsValue: Color(0xFF5CA8F5),
  );

  static const Color pageBackground = Color(0xFF091312);
  static const Color panelBackground = Color(0xFF0E1B1A);
  static const Color surfaceBase = Color(0xFF132423);
  static const Color surfaceRaised = Color(0xFF19302E);
  static const Color borderSubtle = Color(0xFF264543);
  static const Color brandAccent = Color(0xFF5FFFD2);
  static const Color brandAccentSoft = Color(0xFF163E39);
  static const Color textPrimary = Color(0xFFF3FFFC);
  static const Color textMuted = Color(0xFF9FC4BD);
  static const Color success = Color(0xFF7BFFB4);
  static const Color warning = Color(0xFFFFC86F);
  static const Color danger = Color(0xFFFF7D8F);

  static const double radiusSmall = 12;
  static const double radiusMedium = 20;
  static const double radiusLarge = 28;

  static const double spaceXs = 8;
  static const double spaceSm = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 32;

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 260);

  static AppColorPalette colorsOf(BuildContext context) {
    return Theme.of(context).extension<AppColorPalette>() ?? darkPalette;
  }
}
