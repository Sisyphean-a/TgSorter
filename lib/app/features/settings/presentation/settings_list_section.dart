import 'package:flutter/material.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class SettingsListSection extends StatelessWidget {
  const SettingsListSection({
    super.key,
    required this.title,
    required this.children,
    this.highlighted = false,
  });

  final String title;
  final List<Widget> children;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: highlighted ? colors.warning : colors.brandAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.panelBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: highlighted ? colors.warning : colors.borderSubtle,
            ),
          ),
          child: Column(children: _withDividers(context)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(BuildContext context) {
    final colors = AppTokens.colorsOf(context);
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        result.add(
          Divider(
            height: 1,
            color: colors.borderSubtle,
          ),
        );
      }
      result.add(
        Padding(padding: const EdgeInsets.all(12), child: children[index]),
      );
    }
    return result;
  }
}
