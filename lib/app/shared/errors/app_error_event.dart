enum AppErrorScope { auth, settings, pipeline, startup, runtime }

enum AppErrorLevel { info, warning, error }

class AppErrorEvent {
  AppErrorEvent({
    required this.scope,
    required this.level,
    required this.title,
    required this.message,
    DateTime? timestamp,
    this.actionLabel,
    this.actionKey,
  }) : timestamp = timestamp ?? DateTime.now();

  final AppErrorScope scope;
  final AppErrorLevel level;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? actionLabel;
  final String? actionKey;
}

String formatAppErrorEvent(AppErrorEvent event) {
  final timestamp = event.timestamp;
  final hh = timestamp.hour.toString().padLeft(2, '0');
  final mm = timestamp.minute.toString().padLeft(2, '0');
  final ss = timestamp.second.toString().padLeft(2, '0');
  return '[$hh:$mm:$ss] ${event.title}：${event.message}';
}
