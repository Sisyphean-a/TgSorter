import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/core/routing/app_routes.dart';
import 'package:tgsorter/app/theme/app_theme.dart';

class TgSorterApp extends StatelessWidget {
  const TgSorterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TgSorter',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      initialRoute: AppRoutes.auth,
      getPages: buildAppPages(),
    );
  }
}
