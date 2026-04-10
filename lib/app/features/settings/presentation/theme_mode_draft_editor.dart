import 'package:flutter/material.dart';
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
    return DropdownButtonFormField<AppThemeMode>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '主题模式'),
      items: const [
        DropdownMenuItem(value: AppThemeMode.light, child: Text('浅色')),
        DropdownMenuItem(value: AppThemeMode.dark, child: Text('深色')),
        DropdownMenuItem(value: AppThemeMode.system, child: Text('跟随系统')),
      ],
      onChanged: (next) {
        if (next == null) {
          return;
        }
        onChanged(next);
      },
    );
  }
}
