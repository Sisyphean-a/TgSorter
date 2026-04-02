import 'package:flutter/material.dart';
import 'package:tgsorter/app/controllers/settings_controller.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class ShortcutBindingsEditor extends StatelessWidget {
  const ShortcutBindingsEditor({
    super.key,
    required this.controller,
    required this.bindings,
  });

  final SettingsController controller;
  final Map<ShortcutAction, ShortcutBinding> bindings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('桌面快捷键', style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () async {
                    await controller.resetShortcutDefaults();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('快捷键已恢复默认')));
                  },
                  child: const Text('恢复默认'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final action in ShortcutAction.values)
              _ShortcutRow(
                action: action,
                binding: bindings[action] ??
                    AppSettings.defaultShortcutBindings[action]!,
                onSave: (trigger, ctrl) async {
                  await controller.saveShortcutBinding(
                    action: action,
                    trigger: trigger,
                    ctrl: ctrl,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.binding,
    required this.onSave,
  });

  final ShortcutAction action;
  final ShortcutBinding binding;
  final Future<void> Function(ShortcutTrigger trigger, bool ctrl) onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(_labelAction(action))),
          SizedBox(
            width: 130,
            child: DropdownButtonFormField<ShortcutTrigger>(
              initialValue: binding.trigger,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                for (final trigger in ShortcutTrigger.values)
                  DropdownMenuItem(
                    value: trigger,
                    child: Text(_labelTrigger(trigger)),
                  ),
              ],
              onChanged: (next) async {
                if (next == null) {
                  return;
                }
                await _saveAndNotify(
                  context,
                  action: action,
                  trigger: next,
                  ctrl: binding.ctrl,
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              const Text('Ctrl'),
              Switch(
                value: binding.ctrl,
                onChanged: (next) async {
                  await _saveAndNotify(
                    context,
                    action: action,
                    trigger: binding.trigger,
                    ctrl: next,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndNotify(
    BuildContext context, {
    required ShortcutAction action,
    required ShortcutTrigger trigger,
    required bool ctrl,
  }) async {
    try {
      await onSave(trigger, ctrl);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_labelAction(action)} 快捷键已保存')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  String _labelAction(ShortcutAction value) {
    switch (value) {
      case ShortcutAction.previousMessage:
        return '上一条';
      case ShortcutAction.nextMessage:
        return '下一条';
      case ShortcutAction.skipCurrent:
        return '略过此条';
      case ShortcutAction.undoLastStep:
        return '撤销上一步';
      case ShortcutAction.retryNextFailed:
        return '重试下一条';
    }
  }

  String _labelTrigger(ShortcutTrigger value) {
    switch (value) {
      case ShortcutTrigger.digit1:
        return '1';
      case ShortcutTrigger.digit2:
        return '2';
      case ShortcutTrigger.digit3:
        return '3';
      case ShortcutTrigger.keyS:
        return 'S';
      case ShortcutTrigger.keyZ:
        return 'Z';
      case ShortcutTrigger.keyR:
        return 'R';
      case ShortcutTrigger.keyB:
        return 'B';
    }
  }
}
