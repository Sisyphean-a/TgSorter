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
      cardTheme: CardThemeData(
        color: AppTokens.surfaceBase,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
          side: const BorderSide(color: AppTokens.borderSubtle),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTokens.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        ),
      ),
    );
  }
}
