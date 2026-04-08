import 'package:flutter/material.dart';

enum MainShellDestination {
  workspace(label: '工作台', icon: Icons.dashboard_customize_rounded),
  settings(label: '设置', icon: Icons.tune_rounded);

  const MainShellDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
