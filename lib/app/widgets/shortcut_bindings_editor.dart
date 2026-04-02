import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';

class ShortcutBindingsEditor extends StatelessWidget {
  const ShortcutBindingsEditor({
    super.key,
    required this.bindings,
    required this.onChanged,
    required this.onResetDefaults,
  });

  final Map<ShortcutAction, ShortcutBinding> bindings;
  final void Function(
    ShortcutAction action,
    ShortcutTrigger trigger,
    bool ctrl,
  ) onChanged;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onResetDefaults,
            child: const Text('恢复默认'),
          ),
        ),
        const SizedBox(height: 6),
        for (final action in ShortcutAction.values)
          _ShortcutRow(
            action: action,
            binding: bindings[action] ?? AppSettings.defaultShortcutBindings[action]!,
            onChanged: (trigger, ctrl) => onChanged(action, trigger, ctrl),
          ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.action,
    required this.binding,
    required this.onChanged,
  });

  final ShortcutAction action;
  final ShortcutBinding binding;
  final void Function(ShortcutTrigger trigger, bool ctrl) onChanged;

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
              key: ValueKey('${action.name}_${binding.trigger.name}_${binding.ctrl}'),
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
              onChanged: (next) {
                if (next == null) {
                  return;
                }
                onChanged(next, binding.ctrl);
              },
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              const Text('Ctrl'),
              Switch(
                value: binding.ctrl,
                onChanged: (next) => onChanged(binding.trigger, next),
              ),
            ],
          ),
        ],
      ),
    );
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
