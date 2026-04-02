import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, this.appBar, required this.body, this.bottomBar});

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomBar,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTokens.pageBackground, AppTokens.panelBackground],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
