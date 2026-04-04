import 'package:tgsorter/app/models/app_settings.dart';

class SettingsRestartPolicy {
  bool shouldRestart(AppSettings previous, AppSettings next) {
    return previous.proxy != next.proxy;
  }
}
