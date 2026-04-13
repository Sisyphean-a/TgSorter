import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    return _buildTheme(
      brightness: Brightness.light,
      palette: AppTokens.lightPalette,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF3390EC),
        secondary: Color(0xFFE3A008),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFE24D4D),
        onPrimary: Colors.white,
        onSecondary: Color(0xFF2A2000),
        onSurface: Color(0xFF1F2329),
        onError: Colors.white,
      ),
    );
  }

  static ThemeData dark() {
    return _buildTheme(
      brightness: Brightness.dark,
      palette: AppTokens.darkPalette,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5CA8F5),
        secondary: Color(0xFFF4BC42),
        surface: Color(0xFF23262A),
        error: Color(0xFFFF8A80),
        onPrimary: Color(0xFF0C2137),
        onSecondary: Color(0xFF362300),
        onSurface: Color(0xFFF5F7FA),
        onError: Color(0xFF3B0A0A),
      ),
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppColorPalette palette,
    required ColorScheme colorScheme,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.pageBackground,
      cardColor: palette.surfaceBase,
      dividerColor: palette.borderSubtle,
      extensions: [palette],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.settingsAppBar,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.panelBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: BorderSide(color: palette.borderSubtle),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: palette.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: palette.textMuted,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surfaceBase,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: palette.brandAccentSoft,
        side: BorderSide(color: palette.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
        labelStyle: base.textTheme.labelMedium?.copyWith(
          color: palette.brandAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceRaised,
        labelStyle: TextStyle(color: palette.textMuted),
        hintStyle: TextStyle(color: palette.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceMd,
        ),
        border: _inputBorder(palette.borderSubtle),
        enabledBorder: _inputBorder(palette.borderSubtle),
        focusedBorder: _inputBorder(palette.brandAccent),
        errorBorder: _inputBorder(palette.danger),
        focusedErrorBorder: _inputBorder(palette.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: palette.brandAccent,
          foregroundColor: colorScheme.onPrimary,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.textMuted,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: palette.textPrimary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brandAccent,
      ),
      dividerTheme: DividerThemeData(
        color: palette.settingsDivider,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: palette.settingsSurface,
        iconColor: palette.brandAccent,
        textColor: palette.textPrimary,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      borderSide: BorderSide(color: color),
    );
  }
}
