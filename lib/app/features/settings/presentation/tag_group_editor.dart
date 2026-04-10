import 'package:flutter/material.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class TagGroupEditor extends StatefulWidget {
  const TagGroupEditor({
    super.key,
    required this.group,
    required this.onAdd,
    required this.onRemove,
  });

  final TagGroupConfig group;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<TagGroupEditor> createState() => _TagGroupEditorState();
}

class _TagGroupEditorState extends State<TagGroupEditor> {
  late final TextEditingController _tagController;

  @override
  void initState() {
    super.initState();
    _tagController = TextEditingController();
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '默认标签组',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: const InputDecoration(labelText: '新增标签'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _canAdd ? _addTag : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('添加标签'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTags(context),
      ],
    );
  }

  bool get _canAdd => _tagController.text.trim().isNotEmpty;

  Widget _buildTags(BuildContext context) {
    if (widget.group.tags.isEmpty) {
      return Text(
        '暂无标签',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppTokens.textMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in widget.group.tags)
          InputChip(
            label: Text(tag.displayName),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onDeleted: () => widget.onRemove(tag.name),
            deleteButtonTooltipMessage: '删除标签 ${tag.displayName}',
          ),
      ],
    );
  }

  void _addTag() {
    final raw = _tagController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    widget.onAdd(raw);
    _tagController.clear();
    setState(() {});
  }
}
