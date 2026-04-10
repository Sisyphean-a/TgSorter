enum AppThemeMode { light, dark, system }

extension AppThemeModeStorage on AppThemeMode {
  String get storageValue => name;
}

AppThemeMode appThemeModeFromStorage(String? value) {
  for (final mode in AppThemeMode.values) {
    if (mode.storageValue == value) {
      return mode;
    }
  }
  return AppThemeMode.light;
}
