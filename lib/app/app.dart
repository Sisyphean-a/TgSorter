import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/pages/auth_page.dart';
import 'package:tgsorter/app/pages/pipeline_page.dart';
import 'package:tgsorter/app/pages/settings_page.dart';

class TgSorterApp extends StatelessWidget {
  const TgSorterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TgSorter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121517),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF66FF9A),
          secondary: Color(0xFF8BE9FD),
          surface: Color(0xFF1A1F24),
        ),
      ),
      initialRoute: '/auth',
      getPages: [
        GetPage(name: '/auth', page: () => AuthPage()),
        GetPage(name: '/pipeline', page: () => PipelinePage()),
        GetPage(name: '/settings', page: () => SettingsPage()),
      ],
    );
  }
}
