import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_dialogs.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/models/app_theme_mode.dart';

class ThemeModeDraftEditor extends StatelessWidget {
  const ThemeModeDraftEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsValueTile(
      title: '主题模式',
      value: _label(value),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<AppThemeMode>(
          context,
          title: '主题模式',
          selectedValue: value,
          choices: const [
            SettingsChoice(value: AppThemeMode.light, label: '浅色'),
            SettingsChoice(value: AppThemeMode.dark, label: '深色'),
            SettingsChoice(value: AppThemeMode.system, label: '跟随系统'),
          ],
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  String _label(AppThemeMode value) {
    switch (value) {
      case AppThemeMode.light:
        return '浅色';
      case AppThemeMode.dark:
        return '深色';
      case AppThemeMode.system:
        return '跟随系统';
    }
  }
}
