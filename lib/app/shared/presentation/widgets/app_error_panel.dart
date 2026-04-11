import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/shared/errors/app_error_controller.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class AppErrorPanel extends StatelessWidget {
  const AppErrorPanel({super.key, required this.controller});

  final AppErrorController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final history = controller.structuredErrorHistory;
      if (history.isEmpty) {
        return const SizedBox.shrink();
      }
      final colors = AppTokens.colorsOf(context);
      return Container(
        key: const Key('app-error-panel'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.danger.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '错误历史',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: controller.clear,
                  child: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _historyToText(history),
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

String _historyToText(List<AppErrorEvent> history) {
  return history.map(formatAppErrorEvent).join('\n\n');
}
