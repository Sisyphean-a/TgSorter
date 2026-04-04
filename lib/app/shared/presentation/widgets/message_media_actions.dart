import 'package:flutter/material.dart';

typedef MessageMediaActionHandler = Future<void> Function(BuildContext context);

class MessageMediaAction {
  const MessageMediaAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final MessageMediaActionHandler onPressed;
}

class MessageMediaActionStrip extends StatelessWidget {
  const MessageMediaActionStrip({
    super.key,
    required this.actions,
    this.moreActions = const <MessageMediaAction>[],
  });

  final List<MessageMediaAction> actions;
  final List<MessageMediaAction> moreActions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty && moreActions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final action in actions)
          IconButton.filledTonal(
            key: ValueKey('media-action-${action.label}'),
            tooltip: action.label,
            visualDensity: VisualDensity.compact,
            onPressed: () => action.onPressed(context),
            icon: Icon(action.icon, size: 18),
          ),
        if (moreActions.isNotEmpty)
          PopupMenuButton<MessageMediaAction>(
            key: const Key('media-actions-more-menu'),
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) {
              action.onPressed(context);
            },
            itemBuilder: (context) {
              return [
                for (final action in moreActions)
                  PopupMenuItem<MessageMediaAction>(
                    value: action,
                    child: Row(
                      children: [
                        Icon(action.icon, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(action.label)),
                      ],
                    ),
                  ),
              ];
            },
          ),
      ],
    );
  }
}
