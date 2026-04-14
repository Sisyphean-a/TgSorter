import 'package:flutter/material.dart';

enum MainShellDestination {
  forwardingWorkbench(label: '转发工作台', icon: Icons.dashboard_customize_rounded),
  taggingWorkbench(label: '标签工作台', icon: Icons.tag_rounded),
  downloads(label: '下载工作台', icon: Icons.download_rounded),
  settings(label: '设置', icon: Icons.tune_rounded),
  logs(label: '日志', icon: Icons.receipt_long_rounded);

  const MainShellDestination({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
