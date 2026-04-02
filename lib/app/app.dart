import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/pages/auth_page.dart';
import 'package:tgsorter/app/pages/pipeline_page.dart';
import 'package:tgsorter/app/pages/settings_page.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

class TgSorterApp extends StatelessWidget {
  const TgSorterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TgSorter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: '/auth',
      getPages: [
        GetPage(name: '/auth', page: () => AuthPage()),
        GetPage(name: '/pipeline', page: () => PipelinePage()),
        GetPage(name: '/settings', page: () => SettingsPage()),
      ],
    );
  }
}
