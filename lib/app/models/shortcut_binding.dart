enum ShortcutAction {
  previousMessage,
  nextMessage,
  skipCurrent,
  undoLastStep,
  retryNextFailed,
}

enum ShortcutTrigger { digit1, digit2, digit3, keyS, keyZ, keyR, keyB }

class ShortcutBinding {
  const ShortcutBinding({
    required this.action,
    required this.trigger,
    required this.ctrl,
  });

  final ShortcutAction action;
  final ShortcutTrigger trigger;
  final bool ctrl;

  ShortcutBinding copyWith({
    ShortcutAction? action,
    ShortcutTrigger? trigger,
    bool? ctrl,
  }) {
    return ShortcutBinding(
      action: action ?? this.action,
      trigger: trigger ?? this.trigger,
      ctrl: ctrl ?? this.ctrl,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ShortcutBinding &&
            action == other.action &&
            trigger == other.trigger &&
            ctrl == other.ctrl;
  }

  @override
  int get hashCode => Object.hash(action, trigger, ctrl);
}
