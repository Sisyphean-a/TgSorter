import 'package:tgsorter/app/models/app_theme_mode.dart';
import 'package:tgsorter/app/models/default_workbench.dart';

class CommonSettings {
  const CommonSettings({
    required this.themeMode,
    required this.defaultWorkbench,
  });

  final AppThemeMode themeMode;
  final AppDefaultWorkbench defaultWorkbench;
}
