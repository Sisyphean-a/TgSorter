import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';

class AddCategoryDialog extends StatelessWidget {
  const AddCategoryDialog({
    super.key,
    required this.chats,
    required this.onAdd,
  });

  final List<SelectableChat> chats;
  final ValueChanged<SelectableChat> onAdd;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增分类'),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: chats.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final chat = chats[index];
            return ListTile(
              title: Text(chat.title),
              onTap: () {
                onAdd(chat);
                Navigator.of(context).pop();
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
