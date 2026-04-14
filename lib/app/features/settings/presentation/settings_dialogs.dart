import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsChoice<T> {
  const SettingsChoice({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}

Future<T?> showSettingsChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<SettingsChoice<T>> choices,
  T? selectedValue,
}) {
  final palette = AppTokens.colorsOf(context);
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    backgroundColor: palette.settingsSurface,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final choice in choices)
              ListTile(
                title: Text(choice.label),
                subtitle: choice.description == null
                    ? null
                    : Text(choice.description!),
                trailing: selectedValue == choice.value
                    ? Icon(Icons.check_rounded, color: palette.settingsValue)
                    : null,
                onTap: () => Navigator.of(context).pop(choice.value),
              ),
          ],
        ),
      );
    },
  );
}

Future<String?> showSettingsTextEditDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  String? helpText,
  String? Function(String value)? validator,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _SettingsTextEditDialog(
      title: title,
      label: label,
      initialValue: initialValue,
      helpText: helpText,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
    ),
  );
}

class _SettingsTextEditDialog extends StatefulWidget {
  const _SettingsTextEditDialog({
    required this.title,
    required this.label,
    required this.initialValue,
    this.helpText,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? helpText;
  final String? Function(String value)? validator;
  final TextInputType keyboardType;
  final bool obscureText;

  @override
  State<_SettingsTextEditDialog> createState() => _SettingsTextEditDialogState();
}

class _SettingsTextEditDialogState extends State<_SettingsTextEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _errorText = widget.validator?.call(widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helpText,
            errorText: _errorText,
          ),
          onChanged: _handleChanged,
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _errorText == null ? _submit : null,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _handleChanged(String value) {
    setState(() {
      _errorText = widget.validator?.call(value);
    });
  }

  void _submit() {
    if (_errorText != null) {
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }
}
