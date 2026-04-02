import 'package:flutter/material.dart';
import 'package:tgsorter/app/services/telegram_gateway.dart';

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({
    super.key,
    required this.chats,
    required this.onAdd,
  });

  final List<SelectableChat> chats;
  final ValueChanged<SelectableChat> onAdd;

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  int? _selectedChatId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增分类'),
      content: DropdownButtonFormField<int>(
        initialValue: _selectedChatId,
        decoration: const InputDecoration(
          labelText: '目标会话',
          border: OutlineInputBorder(),
        ),
        items: widget.chats
            .map(
              (item) => DropdownMenuItem<int>(
                value: item.id,
                child: Text(item.title),
              ),
            )
            .toList(growable: false),
        onChanged: (next) {
          setState(() {
            _selectedChatId = next;
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedChatId == null
              ? null
              : () {
                  final selected = widget.chats.firstWhere(
                    (item) => item.id == _selectedChatId,
                  );
                  widget.onAdd(selected);
                  Navigator.of(context).pop();
                },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
