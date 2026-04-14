import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/app_settings.dart';
import 'package:tgsorter/app/models/shortcut_binding.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_dialogs.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';

class ShortcutBindingsEditor extends StatelessWidget {
  const ShortcutBindingsEditor({
    super.key,
    required this.bindings,
    required this.onChanged,
    required this.onResetDefaults,
  });

  final Map<ShortcutAction, ShortcutBinding> bindings;
  final void Function(ShortcutAction action, ShortcutTrigger trigger, bool ctrl)
  onChanged;
  final VoidCallback onResetDefaults;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionBlock(
      children: [
        for (final action in ShortcutAction.values)
          _ShortcutRow(
            action: action,
            binding:
                bindings[action] ??
                AppSettings.defaultShortcutBindings[action]!,
            onChanged: (trigger, ctrl) => onChanged(action, trigger, ctrl),
          ),
        SettingsValueTile(
          title: '恢复默认',
          danger: true,
          onTap: onResetDefaults,
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
    return SettingsValueTile(
      title: _labelAction(action),
      subtitle: binding.ctrl ? '当前带 Ctrl 修饰键' : '当前不带 Ctrl 修饰键',
      value: _bindingLabel(binding),
      onTap: () async {
        final selected = await showSettingsChoiceSheet<String>(
          context,
          title: _labelAction(action),
          selectedValue: _bindingLabel(binding),
          choices: [
            for (final ctrl in [false, true])
              for (final trigger in ShortcutTrigger.values)
                SettingsChoice<String>(
                  value: _bindingLabel(
                    ShortcutBinding(action: action, trigger: trigger, ctrl: ctrl),
                  ),
                  label: _bindingLabel(
                    ShortcutBinding(action: action, trigger: trigger, ctrl: ctrl),
                  ),
                ),
          ],
        );
        if (selected == null) {
          return;
        }
        final next = _resolveBinding(selected);
        onChanged(next.trigger, next.ctrl);
      },
    );
  }

  ShortcutBinding _resolveBinding(String value) {
    for (final ctrl in [false, true]) {
      for (final trigger in ShortcutTrigger.values) {
        final binding = ShortcutBinding(
          action: action,
          trigger: trigger,
          ctrl: ctrl,
        );
        if (_bindingLabel(binding) == value) {
          return binding;
        }
      }
    }
    return binding;
  }

  String _bindingLabel(ShortcutBinding value) {
    final trigger = _labelTrigger(value.trigger);
    return value.ctrl ? 'Ctrl + $trigger' : trigger;
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
