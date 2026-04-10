import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';

abstract final class AppThemeScope {
  static ThemeMode resolve(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
