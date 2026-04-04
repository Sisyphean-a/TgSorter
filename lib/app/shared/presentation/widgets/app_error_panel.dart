import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tgsorter/app/controllers/app_error_controller.dart';
import 'package:tgsorter/app/shared/errors/app_error_event.dart';

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
      return Container(
        key: const Key('app-error-panel'),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF31171E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7D3444)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '错误历史',
                    style: TextStyle(
                      color: Colors.white,
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
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _historyToText(history),
                  style: const TextStyle(
                    color: Colors.redAccent,
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
