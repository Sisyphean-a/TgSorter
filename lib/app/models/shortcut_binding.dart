enum ShortcutAction {
  classifyA,
  classifyB,
  classifyC,
  skipCurrent,
  undoLastStep,
  retryNextFailed,
  batchA,
}

enum ShortcutTrigger {
  digit1,
  digit2,
  digit3,
  keyS,
  keyZ,
  keyR,
  keyB,
}

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
}
