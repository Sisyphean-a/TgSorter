import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppTokens.brandAccent,
      secondary: AppTokens.warning,
      surface: AppTokens.surfaceBase,
      error: AppTokens.danger,
      onPrimary: Color(0xFF03211C),
      onSecondary: Color(0xFF291900),
      onSurface: AppTokens.textPrimary,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppTokens.pageBackground,
      cardColor: AppTokens.surfaceBase,
      dividerColor: AppTokens.borderSubtle,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppTokens.textPrimary,
        displayColor: AppTokens.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTokens.panelBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppTokens.borderSubtle),
        ),
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: AppTokens.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: AppTokens.textMuted,
          height: 1.45,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surfaceBase,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppTokens.borderSubtle),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppTokens.brandAccentSoft,
        side: const BorderSide(color: AppTokens.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
        labelStyle: base.textTheme.labelMedium?.copyWith(
          color: AppTokens.brandAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTokens.surfaceRaised,
        labelStyle: const TextStyle(color: AppTokens.textMuted),
        hintStyle: const TextStyle(color: AppTokens.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceMd,
        ),
        border: _inputBorder(AppTokens.borderSubtle),
        enabledBorder: _inputBorder(AppTokens.borderSubtle),
        focusedBorder: _inputBorder(AppTokens.brandAccent),
        errorBorder: _inputBorder(AppTokens.danger),
        focusedErrorBorder: _inputBorder(AppTokens.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          backgroundColor: AppTokens.brandAccent,
          foregroundColor: scheme.onPrimary,
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
          foregroundColor: AppTokens.textPrimary,
          side: const BorderSide(color: AppTokens.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppTokens.textMuted,
          textStyle: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: AppTokens.textPrimary,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppTokens.brandAccent,
      ),
      dividerTheme: const DividerThemeData(
        color: AppTokens.borderSubtle,
        thickness: 1,
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
