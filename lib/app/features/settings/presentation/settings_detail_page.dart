import 'package:flutter/material.dart';

class SettingsDetailPage extends StatelessWidget {
  const SettingsDetailPage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [child],
    );
  }
}
