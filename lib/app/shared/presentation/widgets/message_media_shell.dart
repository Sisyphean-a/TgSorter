import 'package:flutter/material.dart';
import 'package:tgsorter/app/shared/presentation/widgets/message_media_actions.dart';
import 'package:tgsorter/app/theme/app_tokens.dart';

class MessageMediaShell extends StatelessWidget {
  const MessageMediaShell({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.actions = const <MessageMediaAction>[],
    this.moreActions = const <MessageMediaAction>[],
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final List<MessageMediaAction> actions;
  final List<MessageMediaAction> moreActions;

  @override
  Widget build(BuildContext context) {
    final hasActions = actions.isNotEmpty || moreActions.isNotEmpty;
    final colors = AppTokens.colorsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        borderRadius: BorderRadius.circular(AppTokens.radiusMedium),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null || hasActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (header != null) Expanded(child: header!),
                  if (header != null && hasActions)
                    const SizedBox(width: AppTokens.spaceSm),
                  if (hasActions)
                    MessageMediaActionStrip(
                      actions: actions,
                      moreActions: moreActions,
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              child: child,
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: footer!,
            ),
        ],
      ),
    );
  }
}
