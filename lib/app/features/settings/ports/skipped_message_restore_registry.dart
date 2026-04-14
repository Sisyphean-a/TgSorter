import 'package:tgsorter/app/features/settings/ports/skipped_message_restore_port.dart';

class SkippedMessageRestoreRegistry {
  final List<SkippedMessageRestorePort> _targets =
      <SkippedMessageRestorePort>[];

  void register(SkippedMessageRestorePort target) {
    if (_targets.contains(target)) {
      return;
    }
    _targets.add(target);
  }

  List<SkippedMessageRestorePort> get targets =>
      List<SkippedMessageRestorePort>.unmodifiable(_targets);
}
