import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/features/settings/application/settings_coordinator.dart';
import 'package:tgsorter/app/features/settings/application/settings_navigation_controller.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SettingsAppBar({
    required this.controller,
    required this.navigation,
    required this.onSave,
    this.title,
    this.leading,
    super.key,
  });

  final SettingsCoordinator controller;
  final SettingsNavigationController navigation;
  final Future<void> Function() onSave;
  final String? title;
  final Widget? leading;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final palette = AppTokens.colorsOf(context);
      final canPop = navigation.canPop.value;
      final dirty = controller.isDirty.value;
      final resolvedTitle = title ?? navigation.currentTitle;
      return Material(
        color: palette.settingsAppBar,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: preferredSize.height,
            child: Row(
              children: [
                if (canPop)
                  IconButton(
                    onPressed: navigation.backToHome,
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: '返回',
                    color: Colors.white,
                  )
                else if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 4),
                ] else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    resolvedTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canPop && dirty)
                  TextButton(
                    onPressed: onSave,
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
    });
  }
}
