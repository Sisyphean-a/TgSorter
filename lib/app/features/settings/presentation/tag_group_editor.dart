import 'package:flutter/material.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_dialogs.dart';
import 'package:tgsorter/app/features/settings/presentation/settings_telegram_tiles.dart';
import 'package:tgsorter/app/models/tag_config.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class TagGroupEditor extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionBlock(
          children: [
            SettingsValueTile(
              title: '新增标签',
              subtitle: '点击后为默认标签组添加一个新标签',
              onTap: () async {
                final raw = await showSettingsTextEditDialog(
                  context,
                  title: '新增标签',
                  label: '新增标签',
                  initialValue: '',
                  validator: (value) =>
                      value.trim().isEmpty ? '请输入标签名称' : null,
                );
                if (raw == null) {
                  return;
                }
                onAdd(raw);
              },
              trailing: Icon(
                Icons.add_circle_outline,
                color: colors.settingsValue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (group.tags.isEmpty)
          Text(
            '暂无标签',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in group.tags)
                InputChip(
                  label: Text(tag.displayName),
                  onDeleted: () => onRemove(tag.name),
                  deleteButtonTooltipMessage: '删除标签 ${tag.displayName}',
                ),
            ],
          ),
      ],
    );
  }
}
